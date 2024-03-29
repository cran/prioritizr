#' @include Portfolio-class.R
NULL

#' Add a shuffle portfolio
#'
#' Generate a portfolio of solutions for a conservation planning
#' problem by randomly reordering the data prior to
#' solving the problem. This is recommended as a replacement for
#' [add_top_portfolio()] when the *Gurobi* software is not
#' available.
#'
#' @param x [problem()] object.
#'
#' @param number_solutions `integer` number of attempts to generate
#'   different solutions. Defaults to 10.
#'
#' @param threads `integer` number of threads to use for the generating
#'   the solution portfolio. Defaults to 1.
#'
#' @param remove_duplicates `logical` should duplicate solutions
#'   be removed? Defaults to `TRUE`.
#'
#' @details This strategy for generating a portfolio of solutions often
#'   results in different solutions, depending on optimality gap, but may
#'   return duplicate solutions. In general, this strategy is most effective
#'   when problems are quick to solve and multiple threads are available for
#'   solving each problem separately.
#'
#' @inherit add_cuts_portfolio return
#'
#' @seealso
#' See [portfolios] for an overview of all functions for adding a portfolio.
#'
#' @family portfolios
#'
#' @examples
#' \dontrun{
#' # set seed for reproducibility
#' set.seed(500)
#'
#' # load data
#' sim_pu_raster <- get_sim_pu_raster()
#' sim_features <- get_sim_features()
#' sim_zones_pu_raster <- get_sim_zones_pu_raster()
#' sim_zones_features <- get_sim_zones_features()
#'
#' # create minimal problem with shuffle portfolio
#' p1 <-
#'   problem(sim_pu_raster, sim_features) %>%
#'   add_min_set_objective() %>%
#'   add_relative_targets(0.2) %>%
#'   add_shuffle_portfolio(10, remove_duplicates = FALSE) %>%
#'   add_default_solver(gap = 0.2, verbose = FALSE)
#'
#' # solve problem and generate 10 solutions within 20% of optimality
#' s1 <- solve(p1)
#'
#' # convert portfolio into a multi-layer raster
#' s1 <- terra::rast(s1)
#'
#' # print number of solutions found
#' print(terra::nlyr(s1))
#'
#' # plot solutions in portfolio
#' plot(s1, axes = FALSE)
#'
#' # build multi-zone conservation problem with shuffle portfolio
#' p2 <-
#'   problem(sim_zones_pu_raster, sim_zones_features) %>%
#'   add_min_set_objective() %>%
#'   add_relative_targets(matrix(runif(15, 0.1, 0.2), nrow = 5, ncol = 3)) %>%
#'   add_binary_decisions() %>%
#'   add_shuffle_portfolio(10, remove_duplicates = FALSE) %>%
#'   add_default_solver(gap = 0.2, verbose = FALSE)
#'
#' # solve the problem
#' s2 <- solve(p2)
#'
#' # convert each solution in the portfolio into a single category layer
#' s2 <- terra::rast(lapply(s2, category_layer))
#'
#' # print number of solutions found
#' print(terra::nlyr(s2))
#'
#' # plot solutions in portfolio
#' plot(s2, axes = FALSE)
#' }
#' @name add_shuffle_portfolio
NULL

#' @rdname add_shuffle_portfolio
#' @export
add_shuffle_portfolio <- function(x, number_solutions = 10, threads = 1,
                                  remove_duplicates = TRUE) {
  # assert that arguments are valid
  assert_required(x)
  assert_required(number_solutions)
  assert_required(threads)
  assert_required(remove_duplicates)
  assert(
    is_conservation_problem(x),
    assertthat::is.count(number_solutions),
    all_finite(number_solutions),
    is_thread_count(threads),
    all_finite(threads),
    assertthat::is.flag(remove_duplicates),
    assertthat::noNA(remove_duplicates)
  )
  # add portfolio
  x$add_portfolio(
    R6::R6Class(
      "ShufflePortfolio",
      inherit = Portfolio,
      public = list(
        name = "shuffle portfolio",
        data = list(
          number_solutions = number_solutions,
          threads = threads,
          remove_duplicates = remove_duplicates
        ),
        run = function(x, solver) {
          ## attempt initial solution for problem
          initial_sol <- solver$solve(x)
          # if solving the problem failed then return NULL
          if (is.null(initial_sol)) return(initial_sol) # nocov
          if (self$get_data("number_solutions") == 1)
            return(list(initial_sol))
          ## generate additional solutions
          # convert OptimizationProblem to list
          x_list <- as.list(x)
          # define function to generate solution
          generate_solution <- function(i) {
            # create and shuffle problem
            z <- prioritizr::optimization_problem(x_list)
            reorder_key <- z$shuffle_columns()
            # solve problem
            s <- solver$solve(z)
            # reorder variables
            s$x <- s$x[reorder_key]
            # return result
            s
          }
          # generate solutions
          if (self$get_data("threads") > 1L) {
            ## initialize cluster
            cl <- parallel::makeCluster(self$get_data("threads"), "PSOCK")
            ## prepare cluster clean up
            on.exit(try(cl <- parallel::stopCluster(cl), silent = TRUE))
            ## create RNG seeds
            pids <- parallel::clusterEvalQ(cl, Sys.getpid())
            seeds <- sample.int(n = 1e+5, size = self$get_data("threads"))
            names(seeds) <- as.character(unlist(pids))
            ## copy data to cluster
            parallel::clusterExport(
              cl,
              c("solver", "x_list", "seeds", "generate_solution"),
              envir = environment()
            )
            ## initialize RNG on cluster
            parallel::clusterEvalQ(cl, {
              set.seed(seeds[as.character(Sys.getpid())])
              NULL
            })
            ## main processing
            sol <- parallel::parLapply(
              cl = cl,
              seq_len(self$get_data("number_solutions") - 1),
              generate_solution
            )
          } else {
            ## main processing
            sol <- lapply(
              seq_len(self$get_data("number_solutions") - 1),
              generate_solution
            )
          }
          ## compile results
          sol <- append(list(initial_sol), sol)
          if (self$get_data("remove_duplicates")) {
            unique_pos <- !duplicated(
              vapply(lapply(sol, `[[`, 1), paste, character(1), collapse = " ")
            )
            sol <- sol[unique_pos]
          }
          return(sol)
        }
      )
    )$new()
  )
}
