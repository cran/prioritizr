test_that("compile (compressed formulation, single zone)", {
  # import data
  sim_pu_raster <- get_sim_pu_raster()
  sim_features <- get_sim_features()
  sim_phylogeny <- get_sim_phylogeny()
  # calculate budget
  b <- floor(terra::global(sim_pu_raster, "sum", na.rm = TRUE)[[1]]) * 0.25
  # calculate target data
  targ <- floor(terra::global(sim_features, "sum", na.rm = TRUE)[[1]] * 0.25)
  # create problem
  p <-
    problem(sim_pu_raster, sim_features) %>%
    add_max_phylo_end_objective(budget = b, tree = sim_phylogeny) %>%
    add_absolute_targets(targ) %>%
    add_binary_decisions()
  o <- compile(p)
  # calculations for tests
  n_pu <- length(sim_pu_raster[[1]][!is.na(sim_pu_raster)])
  n_f <- terra::nlyr(sim_features)
  n_br <- nrow(sim_phylogeny$edge)
  bm <- branch_matrix(sim_phylogeny)
  pos <- match(sim_phylogeny$tip.label, p$feature_names())
  ab <- matrix(
    rowSums(p$feature_abundances_in_total_units(), na.rm = TRUE),
    ncol = ncol(bm), nrow = nrow(bm), byrow = FALSE
  )
  ab <- Matrix::colSums(ab * bm)
  sim_phylogeny$edge.length <- sim_phylogeny$edge.length * (1 / ab)
  if (min(sim_phylogeny$edge.length) < 1)
    sim_phylogeny$edge.length <-
      sim_phylogeny$edge.length * (1 / min(sim_phylogeny$edge.length))
  scaled_costs <-
    p$planning_unit_costs() *
    c(
      (-0.01 * min(sim_phylogeny$edge.length)) /
      sum(p$planning_unit_costs(), na.rm = TRUE)
    )
  # tests
  expect_equal(o$modelsense(), "max")
  expect_equal(
    o$obj(),
    c(scaled_costs, rep(0, n_f), sim_phylogeny$edge.length)
  )
  expect_equal(o$sense(), c(rep(">=", n_f), "<=", rep(">=", n_br)))
  expect_equal(o$rhs(), c(rep(0, n_f), b, rep(0, n_br)))
  expect_equal(
    o$col_ids(),
    c(rep("pu", n_pu), rep("spp_met", n_f), rep("branch_met", n_br))
  )
  expect_equal(
    o$row_ids(),
    c(rep("spp_target", n_f), "budget", rep("branch_target", n_br))
  )
  expect_true(
    all(o$A()[seq_len(n_f), seq_len(n_pu)] == p$data$rij_matrix[[1]])
  )
  expect_equal(
    o$A()[n_f + 1, ],
    c(p$planning_unit_costs(), rep(0, n_f), rep(0, n_br))
  )
  expect_true(
    all(
      o$A()[seq_len(n_f), n_pu + seq_len(n_f)] ==
      triplet_sparse_matrix(
        i = seq_len(n_f), j = seq_len(n_f), x = (-1 * targ)
      )
    )
  )
  expect_true(
    all(o$A()[n_f + 1 + seq_len(n_br), n_pu + seq_len(n_f)] == Matrix::t(bm))
  )
  expect_true(
    all(
      o$A()[n_f + 1 + seq_len(n_br), n_pu + n_f + seq_len(n_br)] ==
      Matrix::sparseMatrix(
        i = seq_len(n_br), j = seq_len(n_br), x = rep(-1, n_br)
      )
    )
  )
  expect_true(all(o$lb() == 0))
  expect_true(all(o$ub() == 1))
})

test_that("solution (compressed formulation, single zone)", {
  skip_on_cran()
  skip_if_no_fast_solvers_installed()
  # create data
  budget <- 4.23
  cost <- terra::rast(matrix(c(1, 2, NA, 4), nrow = 1))
  locked_out <- 1
  features <- c(
    terra::rast(matrix(c(2, 1, 1, 0), nrow = 1)),
    terra::rast(matrix(c(10, 10, 10, 10), nrow = 1)),
    terra::rast(matrix(c(0, 0, 0, 2), nrow = 1))
  )
  names(features) <- c("layer.1", "layer.2", "layer.3")
  tr <- list(
    tip.label = c("layer.1", "layer.2", "layer.3"),
    edge.length = c(1, 1, 1, 100),
    Nnode = 2L,
    edge = matrix(c(
      4L,  1L,
      4L,  5L,
      5L,  2L,
      5L,  3L
    ), byrow = TRUE, ncol = 2)
  )
  class(tr) <- "phylo"
  attr(tr, "order") <- "cladewise"
  # create problem
  p <-
    problem(cost, features) %>%
    add_max_phylo_end_objective(budget = budget, tree = tr) %>%
    add_absolute_targets(c(2, 12, 2)) %>%
    add_locked_out_constraints(locked_out) %>%
    add_default_solver(gap = 0, verbose = FALSE)
  # solve problem
  s1 <- solve(p)
  s2 <- solve(p)
  # tests
  expect_equal(c(terra::values(s1)), c(0, 0, NA, 1))
  expect_equal(terra::values(s1), terra::values(s2))
})

test_that("compile (expanded formulation)", {
  # import data
  sim_pu_raster <- get_sim_pu_raster()
  sim_features <- get_sim_features()
  sim_phylogeny <- get_sim_phylogeny()
  # calculate budget
  b <- floor(terra::global(sim_pu_raster, "sum", na.rm = TRUE)[[1]]) * 0.25
  # calculate targets data
  targ <- floor(terra::global(sim_features, "sum", na.rm = TRUE)[[1]] * 0.25)
  # create problem
  p <-
    problem(sim_pu_raster, sim_features) %>%
    add_max_phylo_end_objective(budget = b, tree = sim_phylogeny) %>%
    add_absolute_targets(targ) %>%
    add_binary_decisions()
  o <- compile(p, compressed_formulation = FALSE)
  # calculations for tests
  n_pu <- length(sim_pu_raster[[1]][!is.na(sim_pu_raster)])
  n_f <- terra::nlyr(sim_features)
  n_b <- nrow(sim_phylogeny$edge)
  rij <- rij_matrix(sim_pu_raster, sim_features)
  n_rij <- length(rij@x)
  bm <- branch_matrix(sim_phylogeny)
  pos <- match(sim_phylogeny$tip.label, p$feature_names())
  ab <- matrix(
    rowSums(p$feature_abundances_in_total_units(), na.rm = TRUE),
    ncol = ncol(bm), nrow = nrow(bm), byrow = FALSE
  )
  ab <- Matrix::colSums(ab * bm)
  sim_phylogeny$edge.length <- sim_phylogeny$edge.length * (1 / ab)
  if (min(sim_phylogeny$edge.length) < 1)
    sim_phylogeny$edge.length <-
      sim_phylogeny$edge.length * (1 / min(sim_phylogeny$edge.length))
  scaled_costs <-
    p$planning_unit_costs() *
    c(
      (-0.01 * min(sim_phylogeny$edge.length)) /
      sum(p$planning_unit_costs(), na.rm = TRUE)
    )
  # tests
  expect_equal(o$modelsense(), "max")
  expect_equal(
    o$obj(),
    c(scaled_costs, rep(0, n_f), rep(0, n_pu * n_f), sim_phylogeny$edge.length)
  )
  expect_equal(
    o$sense(),
    c(rep("<=", n_rij), rep(">=", n_f), "<=", rep(">=", n_b))
  )
  expect_equal(
    o$rhs(),
    c(rep(0, n_rij), rep(0, n_f), b, rep(0, n_b))
  )
  expect_equal(
    o$col_ids(),
    c(
      rep("pu", n_pu),
      rep("pu_ijz", n_pu * n_f),
      rep("spp_met", n_f),
      rep("branch_met", n_b)
    )
  )
  expect_equal(
    o$row_ids(),
    c(
      rep("pu_ijz", n_rij),
      rep("spp_target", n_f), "budget",
      rep("branch_target", n_b)
    )
  )
  expect_equal(o$lb(), rep(0, n_pu + (n_f * n_pu) + n_f + n_b))
  expect_equal(o$ub(), rep(1, n_pu + (n_f * n_pu) + n_f + n_b))
  # test that problem matrix is correct
  row <- 0
  for (i in seq_len(n_f)) {
    for (j in seq_len(n_pu)) {
      row <- row + 1
      curr_row <- rep(0, n_pu + (n_pu * n_f) + n_f + n_b)
      curr_row[j] <- -1
      curr_row[n_pu + ( (i - 1) * n_pu) + j] <- 1
      expect_equal(o$A()[row, ], curr_row)
    }
  }
  for (i in seq_len(n_f)) {
    curr_row <- rep(0, n_pu + (n_pu * n_f) + n_f + n_b)
    curr_row[(i * n_pu) + seq_len(n_pu)] <- rij[i, ]
    curr_row[n_pu + (n_f * n_pu) + i] <- -1 * targ[i]
    expect_equal(o$A()[(n_f * n_pu) + i, ], curr_row)
  }
  expect_equal(
    o$A()[(n_pu * n_f) + n_f + 1, ],
    c(p$planning_unit_costs(), rep(0, n_f * n_pu), rep(0, n_f), rep(0, n_b))
  )
  for (i in seq_len(n_b)) {
    curr_row <- rep(0, n_pu + (n_f * n_pu) + n_f + n_b)
    curr_row[n_pu + (n_f * n_pu) + which(bm[, i] == 1)] <- 1
    curr_row[n_pu + (n_f * n_pu) + n_f + i] <- -1
    expect_equal(o$A()[(n_f * n_pu) + n_f + 1 + i, ], curr_row)
  }
})

test_that("solution (expanded formulation, single zone)", {
  skip_on_cran()
  skip_if_no_fast_solvers_installed()
  # create data
  cost <- terra::rast(matrix(c(1, 2, NA, 4), nrow = 1))
  budget <- 4.23
  locked_out <- 1
  features <- c(
    terra::rast(matrix(c(2, 1, 1, 0), nrow = 1)),
    terra::rast(matrix(c(10, 10, 10, 10), nrow = 1)),
    terra::rast(matrix(c(0, 0, 0, 2), nrow = 1))
  )
  names(features) <- c("layer.1", "layer.2", "layer.3")
  tr <- list(
    tip.label = c("layer.1", "layer.2", "layer.3"),
    edge.length = c(1, 1, 1, 100),
    Nnode = 2L,
    edge = matrix(c(
      4L,  1L,
      4L,  5L,
      5L,  2L,
      5L,  3L
    ), byrow = TRUE, ncol = 2)
  )
  class(tr) <- "phylo"
  attr(tr, "order") <- "cladewise"
  # create problem
  p <-
    problem(cost, features) %>%
    add_max_phylo_end_objective(budget = budget, tree = tr) %>%
    add_absolute_targets(c(2, 12, 2)) %>%
    add_locked_out_constraints(locked_out) %>%
    add_default_solver(gap = 0, verbose = FALSE)
  # solve problem
  s <- solve(p, compressed_formulation = FALSE)
  # tests
  expect_equal(c(terra::values(s)), c(0, 0, NA, 1))
})

test_that("invalid inputs (single zone)", {
  # import data
  sim_pu_raster <- get_sim_pu_raster()
  sim_features <- get_sim_features()
  sim_phylogeny <- get_sim_phylogeny()
  # tests
  expect_tidy_error(
    problem(sim_pu_raster, sim_features) %>%
      add_max_phylo_end_objective(budget = -5, sim_phylogeny)
  )
  expect_tidy_error(
    problem(sim_pu_raster, sim_features) %>%
      add_max_phylo_end_objective(budget = NA, sim_phylogeny)
  )
  expect_tidy_error(
    problem(sim_pu_raster, sim_features) %>%
      add_max_phylo_end_objective(budget = Inf, sim_phylogeny)
  )
  expect_tidy_error(
    problem(sim_pu_raster, sim_features) %>%
      add_max_phylo_end_objective(
        budget = 5000, ape::drop.tip(sim_phylogeny, "feature_1"))
  )
  expect_tidy_error(
    problem(sim_pu_raster, sim_features) %>%
    add_max_phylo_end_objective(budget = 5, sim_phylogeny) %>%
    compile()
  )
})

test_that("compile (compressed formulation, multiple zones, scalar budget)", {
  # import data
  sim_zones_pu_raster <- get_sim_zones_pu_raster()
  sim_zones_features <- get_sim_zones_features()
  sim_phylogeny <- get_sim_phylogeny()
  # update feature names
  sim_phylogeny$tip.label <- feature_names(sim_zones_features)
  # calculate budget
  b <- min(floor(
    terra::global(sim_zones_pu_raster, "sum", na.rm = TRUE)[[1]] * 0.25
  ))
  # calculate targets data
  targs <- tibble::tibble(
    feature = feature_names(sim_zones_features)[1:3],
    zone = list("zone_1", "zone_2", c("zone_1", "zone_3")),
    sense = c(">=", "<=", ">="),
    target = c(5, 300, 10),
    type = c("absolute", "absolute", "absolute")
  )
  # create problem
  p <-
    problem(sim_zones_pu_raster, sim_zones_features) %>%
    add_max_phylo_end_objective(budget = b, sim_phylogeny) %>%
    add_manual_targets(targs) %>%
    add_binary_decisions()
  o <- compile(p)
  # calculations for tests
  n_pu <- p$number_of_planning_units()
  n_f <- nrow(targs)
  n_z <- p$number_of_zones()
  n_br <- nrow(sim_phylogeny$edge)
  bm <- branch_matrix(sim_phylogeny)
  pos <- match(sim_phylogeny$tip.label, p$feature_names())
  ab <- matrix(
    rowSums(p$feature_abundances_in_total_units(), na.rm = TRUE),
    ncol = ncol(bm), nrow = nrow(bm), byrow = FALSE
  )
  ab <- Matrix::colSums(ab * bm)
  sim_phylogeny$edge.length <- sim_phylogeny$edge.length * (1 / ab)
  if (min(sim_phylogeny$edge.length) < 1)
    sim_phylogeny$edge.length <-
      sim_phylogeny$edge.length * (1 / min(sim_phylogeny$edge.length))
  scaled_costs <-
    c(p$planning_unit_costs()) *
    c(
      (-0.01* min(sim_phylogeny$edge.length)) /
      sum(p$planning_unit_costs(), na.rm = TRUE)
    )
  # tests
  expect_equal(o$modelsense(), "max")
  expect_equal(
    o$obj(),
    c(scaled_costs, rep(0, n_f), sim_phylogeny$edge.length)
  )
  expect_equal(
    o$sense(),
    c(targs$sense, rep("<=", length(b)), rep(">=", n_br), rep("<=", n_pu))
  )
  expect_equal(
    o$rhs(),
    c(rep(0, nrow(targs)), b, rep(0, n_br), rep(1, n_pu))
  )
  expect_equal(
    o$col_ids(),
    c(rep("pu", n_pu * n_z), rep("spp_met", n_f), rep("branch_met", n_br))
  )
  expect_equal(
    o$row_ids(),
    c(
      rep("spp_target", n_f),
      rep("budget", length(b)),
      rep("branch_target", n_br),
      rep("pu_zone", n_pu)
    )
  )
  expect_equal(o$lb(), rep(0, (n_pu * n_z) + n_f + n_br))
  expect_equal(o$ub(), rep(1, (n_pu * n_z) + n_f + n_br))
  # check that problem matrix is correct
  m <- matrix(
    0, nrow = nrow(targs) + length(b) + n_br + n_pu,
    ncol = (n_pu * n_z) + nrow(targs) + n_br
  )
  counter <- 0
  for (i in seq_len(nrow(targs))) {
    zs <- match(targs$zone[[i]], zone_names(sim_zones_features))
    f <- match(targs$feature[i], feature_names(sim_zones_features))
    counter <- counter + 1
    for (z in zs)
      m[counter, ((z - 1) * n_pu) + seq_len(n_pu)] <-
        p$data$rij_matrix[[z]][f, ]
    m[counter, (n_z * n_pu) + i] <- -1 * targs$target[i]
  }
  counter <- counter + 1
  m[counter, seq_len(n_pu * n_z)] <- c(p$planning_unit_costs())
  for (br in seq_len(n_br)) {
    counter <- counter + 1
    m[counter, (n_pu * n_z) + which(bm[1:3, br] == 1)] <- 1
    m[counter, (n_pu * n_z) + n_f + br] <- -1
  }
  for (i in seq_len(n_pu)) {
    m[i + counter, i] <- 1
    m[i + counter, n_pu + i] <- 1
    m[i + counter, (2 * n_pu) + i] <- 1
  }
  m <- as(m, "Matrix")
  expect_true(all(o$A() == m))
})

test_that("solve (compressed formulation, multiple zones, scalar budget)", {
  skip_on_cran()
  skip_if_no_fast_solvers_installed()
  # create data
  budget <- 20
  cost <- c(
    terra::rast(matrix(c(5,  6,  7,  8,  NA, NA), nrow = 1)),
    terra::rast(matrix(c(11, 12, 13, 14, NA, 15), nrow = 1))
  )
  features <- c(
    # zone_1
    terra::rast(matrix(c(1,  1,  1, 1, 1, 1), nrow = 1)),
    terra::rast(matrix(c(1,  1,  1, 1, 1, 1), nrow = 1)),
    terra::rast(matrix(c(2,  1,  1, 1, 1, 1), nrow = 1)),
    # zone_2
    terra::rast(matrix(c(1,  1,  1, 1, 1, 1), nrow = 1)),
    terra::rast(matrix(c(1,  1,  1, 1, 1, 1), nrow = 1)),
    terra::rast(matrix(c(1,  1,  1, 1, 1, 3), nrow = 1))
  )
  targs <- tibble::tibble(
    feature = c("layer.1", "layer.2", "layer.3"),
    zone = list("1", "1", c("1", "2")),
    sense = rep(">=", 3),
    type = "absolute",
    target = c(1, 1, 5)
  )
  tr <- list(
    tip.label = c("layer.1", "layer.2", "layer.3"),
    edge.length = c(1, 1, 1, 100),
    Nnode = 2L,
    edge = matrix(c(
      4L,  1L,
      4L,  5L,
      5L,  2L,
      5L,  3L
    ), byrow = TRUE, ncol = 2))
  class(tr) <- "phylo"
  attr(tr, "order") <- "cladewise"
  # create problem
  p <-
    problem(
      cost,
      zones(features[[1:3]], features[[4:6]], feature_names = targs$feature)
    ) %>%
    add_max_phylo_end_objective(budget = budget, tree = tr) %>%
    add_manual_targets(targs) %>%
    add_default_solver(gap = 0, verbose = FALSE)
  # solve problem
  s <- solve(p)
  # test for correct solution
  expect_equal(c(terra::values(s[[1]])), c(1, 0, 0, 0, NA, NA))
  expect_equal(c(terra::values(s[[2]])), c(0, 0, 0, 0, NA, 1))
})

test_that("compile (compressed formulation, multiple zones, vector budget)", {
  # import data
  sim_zones_pu_raster <- get_sim_zones_pu_raster()
  sim_zones_features <- get_sim_zones_features()
  sim_phylogeny <- get_sim_phylogeny()
  # update feature names
  sim_phylogeny$tip.label <- feature_names(sim_zones_features)
  # calculate budget
  b <- floor(
    terra::global(sim_zones_pu_raster, "sum", na.rm = TRUE)[[1]] * 0.25
  )
  # calculate targets data
  targs <- tibble::tibble(
    feature = feature_names(sim_zones_features)[1:3],
    zone = list("zone_1", "zone_2", c("zone_1", "zone_3")),
    sense = c(">=", "<=", ">="),
    target = c(5, 300, 10),
    type = c("absolute", "absolute", "absolute")
  )
  # create problem
  p <-
    problem(sim_zones_pu_raster, sim_zones_features) %>%
    add_max_phylo_end_objective(budget = b, sim_phylogeny) %>%
    add_manual_targets(targs) %>%
    add_binary_decisions()
  o <- compile(p)
  # calculations for tests
  n_pu <- p$number_of_planning_units()
  n_f <- nrow(targs)
  n_z <- p$number_of_zones()
  n_br <- nrow(sim_phylogeny$edge)
  bm <- branch_matrix(sim_phylogeny)
  pos <- match(sim_phylogeny$tip.label, p$feature_names())
  ab <- matrix(
    rowSums(p$feature_abundances_in_total_units(), na.rm = TRUE),
    ncol = ncol(bm), nrow = nrow(bm), byrow = FALSE
  )
  ab <- Matrix::colSums(ab * bm)
  sim_phylogeny$edge.length <- sim_phylogeny$edge.length * (1 / ab)
  if (min(sim_phylogeny$edge.length) < 1)
    sim_phylogeny$edge.length <-
      sim_phylogeny$edge.length * (1 / min(sim_phylogeny$edge.length))
  scaled_costs <-
    c(p$planning_unit_costs()) *
    c(
      (-0.01 * min(sim_phylogeny$edge.length)) /
      sum(p$planning_unit_costs(), na.rm = TRUE)
    )
  # tests
  expect_equal(o$modelsense(), "max")
  expect_equal(
    o$obj(),
    c(scaled_costs, rep(0, n_f), sim_phylogeny$edge.length)
  )
  expect_equal(
    o$sense(),
    c(targs$sense, rep("<=", length(b)), rep(">=", n_br), rep("<=", n_pu))
  )
  expect_equal(
    o$rhs(),
    c(rep(0, nrow(targs)), b, rep(0, n_br), rep(1, n_pu))
  )
  expect_equal(
    o$col_ids(),
    c(rep("pu", n_pu * n_z), rep("spp_met", n_f), rep("branch_met", n_br))
  )
  expect_equal(
    o$row_ids(),
    c(
      rep("spp_target", n_f),
      rep("budget", length(b)),
      rep("branch_target", n_br),
      rep("pu_zone", n_pu)
    )
  )
  expect_equal(o$lb(), rep(0, (n_pu * n_z) + n_f + n_br))
  expect_equal(o$ub(), rep(1, (n_pu * n_z) + n_f + n_br))
  # check that problem matrix is correct
  m <- matrix(
    0, nrow = nrow(targs) + length(b) + n_br + n_pu,
    ncol = (n_pu * n_z) + nrow(targs) + n_br
  )
  counter <- 0
  for (i in seq_len(nrow(targs))) {
    zs <- match(targs$zone[[i]], zone_names(sim_zones_features))
    f <- match(targs$feature[i], feature_names(sim_zones_features))
    counter <- counter + 1
    for (z in zs)
      m[counter, ((z - 1) * n_pu) + seq_len(n_pu)] <-
        p$data$rij_matrix[[z]][f, ]
    m[counter, (n_z * n_pu) + i] <- -1 * targs$target[i]
  }
  for (i in seq_along(b)) {
    counter <- counter + 1
    m[counter, ((i - 1) * n_pu) + seq_len(n_pu)] <- p$planning_unit_costs()[, i]
  }
  for (br in seq_len(n_br)) {
    counter <- counter + 1
    m[counter, (n_pu * n_z) + which(bm[1:3, br] == 1)] <- 1
    m[counter, (n_pu * n_z) + n_f + br] <- -1
  }
  for (i in seq_len(n_pu)) {
    m[i + counter, i] <- 1
    m[i + counter, n_pu + i] <- 1
    m[i + counter, (2 * n_pu) + i] <- 1
  }
  m <- as(m, "Matrix")
  expect_true(all(o$A() == m))
})

test_that("solve (compressed formulation, multiple zones, vector budget)", {
  skip_on_cran()
  skip_if_no_fast_solvers_installed()
  # create data
  budget <- c(5, 15)
  cost <- c(
    terra::rast(matrix(c(5,  6,  7,  8,  NA, NA), nrow = 1)),
    terra::rast(matrix(c(11, 12, 13, 14, NA, 15), nrow = 1))
  )
  features <- c(
    # zone_1
    terra::rast(matrix(c(1,  1,  1, 1, 1, 1), nrow = 1)),
    terra::rast(matrix(c(1,  1,  1, 1, 1, 1), nrow = 1)),
    terra::rast(matrix(c(2,  1,  1, 1, 1, 1), nrow = 1)),
    # zone_2
    terra::rast(matrix(c(1,  1,  1, 1, 1, 1), nrow = 1)),
    terra::rast(matrix(c(1,  1,  1, 1, 1, 1), nrow = 1)),
    terra::rast(matrix(c(1,  1,  1, 1, 1, 3), nrow = 1))
  )
  targs <- tibble::tibble(
    feature = c("layer.1", "layer.2", "layer.3"),
    zone = list("1", "1", c("1", "2")),
    sense = rep(">=", 3),
    type = "absolute",
    target = c(1, 1, 5)
  )
  tr <- list(
    tip.label = c("layer.1", "layer.2", "layer.3"),
    edge.length = c(1, 1, 1, 100),
    Nnode = 2L,
    edge = matrix(c(
      4L,  1L,
      4L,  5L,
      5L,  2L,
      5L,  3L
    ), byrow = TRUE, ncol = 2)
  )
  class(tr) <- "phylo"
  attr(tr, "order") <- "cladewise"
  # create problem
  p <-
    problem(
      cost,
      zones(features[[1:3]], features[[4:6]], feature_names = targs$feature)
    ) %>%
    add_max_phylo_end_objective(budget = budget, tree = tr) %>%
    add_manual_targets(targs) %>%
    add_default_solver(gap = 0, verbose = FALSE)
  # solve problem
  s <- solve(p)
  # tests
  expect_equal(c(terra::values(s[[1]])), c(1, 0, 0, 0, NA, NA))
  expect_equal(c(terra::values(s[[2]])), c(0, 0, 0, 0, NA, 1))
})

test_that("compile (expanded formulation, multiple zones, scalar budget)", {
  # import data
  sim_zones_pu_raster <- get_sim_zones_pu_raster()
  sim_zones_features <- get_sim_zones_features()
  sim_phylogeny <- get_sim_phylogeny()
  # update feature names
  sim_phylogeny$tip.label <- feature_names(sim_zones_features)
  # calculate budget
  b <- min(floor(
    terra::global(sim_zones_pu_raster, "sum", na.rm = TRUE)[[1]] * 0.25
  ))
  # create targets data
  targs <- tibble::tibble(
    feature = feature_names(sim_zones_features)[1:3],
    zone = list("zone_1", "zone_2", c("zone_1", "zone_3")),
    sense = c(">=", "<=", ">="),
    target = c(5, 300, 10),
    type = c("absolute", "absolute", "absolute")
  )
  # create problem
  p <-
    problem(sim_zones_pu_raster, sim_zones_features) %>%
    add_max_phylo_end_objective(budget = b, sim_phylogeny) %>%
    add_manual_targets(targs) %>%
    add_binary_decisions()
  o <- compile(p, compressed_formulation = FALSE)
  # calculations for tests
  n_pu <- p$number_of_planning_units()
  n_f <- p$number_of_features()
  n_t <- nrow(targs)
  n_z <- p$number_of_zones()
  n_br <- nrow(sim_phylogeny$edge)
  bm <- branch_matrix(sim_phylogeny)
  pos <- match(sim_phylogeny$tip.label, p$feature_names())
  ab <- matrix(
    rowSums(p$feature_abundances_in_total_units(), na.rm = TRUE),
    ncol = ncol(bm), nrow = nrow(bm), byrow = FALSE
  )
  ab <- Matrix::colSums(ab * bm)
  sim_phylogeny$edge.length <- sim_phylogeny$edge.length * (1 / ab)
  if (min(sim_phylogeny$edge.length) < 1)
    sim_phylogeny$edge.length <-
      sim_phylogeny$edge.length * (1 / min(sim_phylogeny$edge.length))
  scaled_costs <-
    c(p$planning_unit_costs()) *
    c(
      (-0.01 * min(sim_phylogeny$edge.length)) /
      sum(p$planning_unit_costs(), na.rm = TRUE)
    )
  # tests
  expect_equal(o$modelsense(), "max")
  expect_equal(
    o$obj(),
    c(
      scaled_costs, rep(0, n_pu * n_z * n_f), rep(0, n_t),
      sim_phylogeny$edge.length
    )
  )
  expect_equal(
    o$sense(),
    c(
      rep("<=", n_f * n_z * n_pu), targs$sense, rep("<=", length(b)),
      rep(">=", n_br), rep("<=", n_pu)
    )
  )
  expect_equal(
    o$rhs(),
    c(
      rep(0, n_pu * n_z * n_f), rep(0, nrow(targs)), b, rep(0, n_br),
      rep(1, n_pu)
    )
  )
  expect_equal(
    o$col_ids(),
    c(
      rep("pu", n_pu * n_z),
      rep("pu_ijz", n_pu * n_z * n_f),
      rep("spp_met", n_t),
      rep("branch_met", n_br)
    )
  )
  expect_equal(
    o$row_ids(),
    c(
      rep("pu_ijz", n_pu * n_z * n_f),
      rep("spp_target", n_t),
      rep("budget", length(b)),
      rep("branch_target", n_br),
      rep("pu_zone", n_pu)
    )
  )
  expect_equal(o$lb(), rep(0, (n_pu * n_z) + (n_pu * n_z * n_f) + n_t + n_br))
  expect_equal(o$ub(), rep(1, (n_pu * n_z) + (n_pu * n_z * n_f) + n_t + n_br))
  # check that problem matrix is correct
  m <- matrix(
    0, nrow = (n_pu * n_z * n_f) + n_t + length(b) + n_br + n_pu,
    ncol = (n_pu * n_z) + (n_pu * n_z * n_f) + n_t + n_br
  )
  counter <- 0
  for (z in seq_len(n_z)) {
    for (i in seq_len(n_f)) {
      for (j in seq_len(n_pu)) {
        counter <- counter + 1
        m[counter, ((z - 1) * n_pu) + j] <- -1
        idx <- (n_pu * n_z) + ((z - 1) * n_pu * n_f) + ((i - 1) * n_pu) + j
        m[counter, idx] <- 1
      }
    }
  }
  for (i in seq_len(nrow(targs))) {
    zs <- match(targs$zone[[i]], zone_names(sim_zones_features))
    f <- match(targs$feature[i], feature_names(sim_zones_features))
    counter <- counter + 1
    for (z in zs) {
      for (pu in seq_len(n_pu)) {
        col <- (n_pu * n_z) + ((z - 1) * n_f * n_pu) + ((f - 1) * n_pu) + pu
        m[counter, col] <- p$data$rij_matrix[[z]][f, pu]
      }
      col <- (n_pu * n_z) + (n_pu * n_f * n_z) + i
      m[counter, col] <- -1 * targs$target[i]
    }
  }
  counter <- counter + 1
  m[counter, seq_len(n_pu * n_z)] <- c(p$planning_unit_costs())
  for (br in seq_len(n_br)) {
    counter <- counter + 1
    m[counter, (n_pu * n_z) + (n_pu * n_z * n_f) + which(bm[1:3, br] == 1)] <- 1
    m[counter, (n_pu * n_z) + (n_pu * n_z * n_f) + n_t + br] <- -1
  }
  for (i in seq_len(n_pu)) {
    m[i + counter, i] <- 1
    m[i + counter, n_pu + i] <- 1
    m[i + counter, (2 * n_pu) + i] <- 1
  }
  m <- as(m, "Matrix")
  expect_true(all(o$A() == m))
})

test_that("solve (expanded formulation, multiple zones, scalar budget)", {
  skip_on_cran()
  skip_if_no_fast_solvers_installed()
  # create data
  budget <- 20
  cost <- c(
    terra::rast(matrix(c(5,  6,  7,  8,  NA, NA), nrow = 1)),
    terra::rast(matrix(c(11, 12, 13, 14, NA, 15), nrow = 1))
  )
  features <- c(
    # zone_1
    terra::rast(matrix(c(1,  1,  1, 1, 1, 1), nrow = 1)),
    terra::rast(matrix(c(1,  1,  1, 1, 1, 1), nrow = 1)),
    terra::rast(matrix(c(2,  1,  1, 1, 1, 1), nrow = 1)),
    # zone_2
    terra::rast(matrix(c(1,  1,  1, 1, 1, 1), nrow = 1)),
    terra::rast(matrix(c(1,  1,  1, 1, 1, 1), nrow = 1)),
    terra::rast(matrix(c(1,  1,  1, 1, 1, 3), nrow = 1))
  )
  targs <- tibble::tibble(
    feature = c("layer.1", "layer.2", "layer.3"),
    zone = list("1", "1", c("1", "2")),
    sense = rep(">=", 3),
    type = "absolute",
    target = c(1, 1, 5)
  )
  tr <- list(
    tip.label = c("layer.1", "layer.2", "layer.3"),
    edge.length = c(1, 1, 1, 100),
    Nnode = 2L,
    edge = matrix(c(
      4L,  1L,
      4L,  5L,
      5L,  2L,
      5L,  3L
    ), byrow = TRUE, ncol = 2)
  )
  class(tr) <- "phylo"
  attr(tr, "order") <- "cladewise"
  # create problem
  p <-
    problem(
      cost,
      zones(features[[1:3]], features[[4:6]], feature_names = targs$feature)
    ) %>%
    add_max_phylo_end_objective(budget = budget, tree = tr) %>%
    add_manual_targets(targs) %>%
    add_default_solver(gap = 0, verbose = FALSE)
  # solve problem
  s <- solve(p, compressed_formulation = FALSE)
  # tests
  expect_equal(c(terra::values(s[[1]])), c(1, 0, 0, 0, NA, NA))
  expect_equal(c(terra::values(s[[2]])), c(0, 0, 0, 0, NA, 1))
})

test_that("compile (expanded formulation, multiple zones, vector budget)", {
  # import data
  sim_zones_pu_raster <- get_sim_zones_pu_raster()
  sim_zones_features <- get_sim_zones_features()
  sim_phylogeny <- get_sim_phylogeny()
  # crop spatial extent of data
  sim_zones_pu_raster <- terra::crop(
    sim_zones_pu_raster, terra::ext(0, 0.1, 0, 0.1)
  )
  for (i in 1:3)
    sim_zones_features[[i]] <- terra::crop(
      sim_zones_features[[i]], sim_zones_pu_raster
    )
  # update feature names
  sim_phylogeny$tip.label <- feature_names(sim_zones_features)
  # calculate budget
  b <- floor(
    terra::global(sim_zones_pu_raster, "sum", na.rm = TRUE)[[1]] * 0.25
  )
  # calculate targets data
  targs <- tibble::tibble(
    feature = feature_names(sim_zones_features)[1:3],
    zone = list("zone_1", "zone_2", c("zone_1", "zone_3")),
    sense = c(">=", "<=", ">="),
    target = c(5, 300, 10),
    type = c("absolute", "absolute", "absolute")
  )
  # create problem
  p <-
    problem(sim_zones_pu_raster, sim_zones_features) %>%
    add_max_phylo_end_objective(budget = b, sim_phylogeny) %>%
    add_manual_targets(targs) %>%
    add_binary_decisions()
  o <- compile(p, compressed_formulation = FALSE)
  # calculations for tests
  n_pu <- p$number_of_planning_units()
  n_f <- p$number_of_features()
  n_t <- nrow(targs)
  n_z <- p$number_of_zones()
  n_br <- nrow(sim_phylogeny$edge)
  bm <- branch_matrix(sim_phylogeny)
  pos <- match(sim_phylogeny$tip.label, p$feature_names())
  ab <- matrix(
    rowSums(p$feature_abundances_in_total_units(), na.rm = TRUE),
    ncol = ncol(bm), nrow = nrow(bm), byrow = FALSE
  )
  ab <- Matrix::colSums(ab * bm)
  sim_phylogeny$edge.length <- sim_phylogeny$edge.length * (1 / ab)
  if (min(sim_phylogeny$edge.length) < 1)
    sim_phylogeny$edge.length <-
      sim_phylogeny$edge.length * (1 / min(sim_phylogeny$edge.length))
  scaled_costs <-
    c(p$planning_unit_costs()) *
    c(
      (-0.01 * min(sim_phylogeny$edge.length)) /
      sum(p$planning_unit_costs(), na.rm = TRUE)
    )
  # tests
  expect_equal(o$modelsense(), "max")
  expect_equal(
    o$obj(),
    c(
      scaled_costs, rep(0, n_pu * n_z * n_f), rep(0, n_t),
      sim_phylogeny$edge.length
    )
  )
  expect_equal(
    o$sense(),
    c(
      rep("<=", n_f * n_z * n_pu), targs$sense,
      rep("<=", length(b)), rep(">=", n_br), rep("<=", n_pu)
    )
  )
  expect_equal(
    o$rhs(),
    c(
      rep(0, n_pu * n_z * n_f), rep(0, nrow(targs)), b, rep(0, n_br),
      rep(1, n_pu)
    )
  )
  expect_equal(
    o$col_ids(),
    c(
      rep("pu", n_pu * n_z),
      rep("pu_ijz", n_pu * n_z * n_f),
      rep("spp_met", n_t),
      rep("branch_met", n_br)
    )
  )
  expect_equal(
    o$row_ids(),
    c(
      rep("pu_ijz", n_pu * n_z * n_f),
      rep("spp_target", n_t),
      rep("budget", length(b)),
      rep("branch_target", n_br),
      rep("pu_zone", n_pu)
    )
  )
  expect_equal(o$lb(), rep(0, (n_pu * n_z) + (n_pu * n_z * n_f) + n_t + n_br))
  expect_equal(o$ub(), rep(1, (n_pu * n_z) + (n_pu * n_z * n_f) + n_t + n_br))
  # check that problem matrix is correct
  m <- matrix(
    0, nrow = (n_pu * n_z * n_f) + n_t + length(b) + n_br + n_pu,
    ncol = (n_pu * n_z) + (n_pu * n_z * n_f) + n_t + n_br
  )
  counter <- 0
  for (z in seq_len(n_z)) {
    for (i in seq_len(n_f)) {
      for (j in seq_len(n_pu)) {
        counter <- counter + 1
        m[counter, ((z - 1) * n_pu) + j] <- -1
        idx <- (n_pu * n_z) + ((z - 1) * n_pu * n_f) + ((i - 1) * n_pu) + j
        m[counter, idx] <- 1
      }
    }
  }
  for (i in seq_len(nrow(targs))) {
    zs <- match(targs$zone[[i]], zone_names(sim_zones_features))
    f <- match(targs$feature[i], feature_names(sim_zones_features))
    counter <- counter + 1
    for (z in zs) {
      for (pu in seq_len(n_pu)) {
        col <- (n_pu * n_z) + ((z - 1) * n_f * n_pu) + ((f - 1) * n_pu) + pu
        m[counter, col] <- p$data$rij_matrix[[z]][f, pu]
      }
      col <- (n_pu * n_z) + (n_pu * n_f * n_z) + i
      m[counter, col] <- -1 * targs$target[i]
    }
  }
  for (i in seq_len(n_z)) {
    counter <- counter + 1
    m[counter, ((i - 1) * n_pu) + seq_len(n_pu)] <- p$planning_unit_costs()[, i]
  }
  for (br in seq_len(n_br)) {
    counter <- counter + 1
    m[counter, (n_pu * n_z) + (n_pu * n_z * n_f) + which(bm[1:3, br] == 1)] <- 1
    m[counter, (n_pu * n_z) + (n_pu * n_z * n_f) + n_t + br] <- -1
  }
  for (i in seq_len(n_pu)) {
    m[i + counter, i] <- 1
    m[i + counter, n_pu + i] <- 1
    m[i + counter, (2 * n_pu) + i] <- 1
  }
  m <- as(m, "Matrix")
  expect_true(all(o$A() == m))
})

test_that("solve (expanded formulation, multiple zones, vector budget)", {
  skip_on_cran()
  skip_if_no_fast_solvers_installed()
  # create data
  budget <- c(5, 15)
  cost <- c(
    terra::rast(matrix(c(5,  6,  7,  8,  NA, NA), nrow = 1)),
    terra::rast(matrix(c(11, 12, 13, 14, NA, 15), nrow = 1)))
  features <- c(
    # zone_1
    terra::rast(matrix(c(1,  1,  1, 1, 1, 1), nrow = 1)),
    terra::rast(matrix(c(1,  1,  1, 1, 1, 1), nrow = 1)),
    terra::rast(matrix(c(2,  1,  1, 1, 1, 1), nrow = 1)),
    # zone_2
    terra::rast(matrix(c(1,  1,  1, 1, 1, 1), nrow = 1)),
    terra::rast(matrix(c(1,  1,  1, 1, 1, 1), nrow = 1)),
    terra::rast(matrix(c(1,  1,  1, 1, 1, 3), nrow = 1))
  )
  targs <- tibble::tibble(
    feature = c("layer.1", "layer.2", "layer.3"),
    zone = list("1", "1", c("1", "2")),
    sense = rep(">=", 3),
    type = "absolute",
    target = c(1, 1, 5)
  )
  tr <- list(
    tip.label = c("layer.1", "layer.2", "layer.3"),
    edge.length = c(1, 1, 1, 100),
    Nnode = 2L,
    edge = matrix(c(
      4L,  1L,
      4L,  5L,
      5L,  2L,
      5L,  3L
    ), byrow = TRUE, ncol = 2)
  )
  class(tr) <- "phylo"
  attr(tr, "order") <- "cladewise"
  # create problem
  p <-
    problem(
      cost,
      zones(features[[1:3]], features[[4:6]], feature_names = targs$feature)
    ) %>%
    add_max_phylo_end_objective(budget = budget, tree = tr) %>%
    add_manual_targets(targs) %>%
    add_default_solver(gap = 0, verbose = FALSE)
  # solve problem
  s <- solve(p, compressed_formulation = FALSE)
  # tests
  expect_equal(c(terra::values(s[[1]])), c(1, 0, 0, 0, NA, NA))
  expect_equal(c(terra::values(s[[2]])), c(0, 0, 0, 0, NA, 1))
})

test_that("invalid inputs (multiple zones)", {
  # import data
  sim_zones_pu_raster <- get_sim_zones_pu_raster()
  sim_zones_features <- get_sim_zones_features()
  sim_phylogeny <- get_sim_phylogeny()
  # update feature names
  sim_phylogeny$tip.label <- feature_names(sim_zones_features)
  # tests
  expect_tidy_error(
    problem(sim_zones_pu_raster, sim_zones_features) %>%
    add_max_phylo_end_objective(budget = c(1, -5, 1), sim_phylogeny)
  )
  expect_tidy_error(
    problem(sim_zones_pu_raster, sim_zones_features) %>%
    add_max_phylo_end_objective(budget = c(1, NA, 1), sim_phylogeny)
  )
  expect_tidy_error(
    problem(sim_zones_pu_raster, sim_zones_features) %>%
    add_max_phylo_end_objective(budget = c(NA, NA, NA), sim_phylogeny)
  )
  expect_tidy_error(
    problem(sim_zones_pu_raster, sim_zones_features) %>%
    add_max_phylo_end_objective(budget = c(1, Inf, 9), sim_phylogeny)
  )
  expect_tidy_error(
    problem(sim_zones_pu_raster, sim_zones_features) %>%
    add_max_phylo_end_objective(budget = c(1, Inf, 9), sim_phylogeny)
  )
  expect_tidy_error(
    problem(sim_zones_pu_raster, sim_zones_features) %>%
    add_max_phylo_end_objective(
      budget = 5000, ape::drop.tip(sim_phylogeny, "feature_1"))
  )
  expect_tidy_error(
    problem(sim_zones_pu_raster, sim_zones_features) %>%
    add_max_phylo_end_objective(budget = c(5, 5, 5), sim_phylogeny) %>%
    compile()
  )
})
