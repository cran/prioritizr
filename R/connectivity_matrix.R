#' @include internal.R
NULL

#' Connectivity matrix
#'
#' Create a matrix showing the connectivity between planning units. Connectivity
#' is calculated as the average conductance of two planning units multiplied
#' by the amount of shared boundary between the two planning units. Thus
#' planning units that each have higher a conductance and share a greater
#' boundary are associated with greater connectivity.
#'
#' @param x [`Raster-class`],
#'   [`SpatialPolygonsDataFrame-class`],
#'   [`SpatialLinesDataFrame-class`],
#'   or [sf::sf()] object
#'   representing planning units.
#'   If `x` is a [`Raster-class`] object then it must
#'   contain a single layer.
#'
#' @param y [`Raster-class`] object showing the conductance
#'   of different areas across the study area, or a `character` object
#'   denoting a column name in the attribute table of `x` that contains
#'   the conductance values. Note that argument to `y` can only be a
#'   `character` object if the argument to `x` is a
#'   [`Spatial-class`] or [sf::sf()] object.
#'   Also, note that if the argument to `x` is a
#'   [`Raster-class`] object then
#'   argument to `y` must have the same spatial properties as it
#'   (i.e. coordinate system, extent, resolution).
#'
#' @param ... additional arguments passed to [fast_extract()] for
#'   extracting and calculating the conductance values for each planning unit.
#'   These arguments are only used if argument to `x` is a
#'   \code{link[sp]{Spatial-class}} or [sf::sf()] object and argument
#'   to `y` is a [`Raster-class`] object.
#'
#' @details Shared boundary calculations are performed using
#'   [boundary_matrix()].
#'
#' @return [`dsCMatrix-class`] symmetric sparse matrix object.
#'   Each row and column represents a planning unit.
#'   Cells values indicate the connectivity between different pairs of planning
#'   units.
#'   To reduce computational burden, cells among the matrix diagonal are
#'   set to zero. Furthermore, if the argument to `x` is a
#'   [`Raster-class`] object, then cells with `NA`
#'   values are set to zero too.
#'
#' @name connectivity_matrix
#'
#' @rdname connectivity_matrix
#'
#' @examples
#' # load data
#' data(sim_pu_raster, sim_pu_sf, sim_features)
#'
#' # create connectivity matrix using raster planning unit data using
#' # the raster cost values to represent conductance
#' ## extract 9 planning units
#' r <- crop(sim_pu_raster, c(0, 0.3, 0, 0.3))
#'
#' ## extract conductance data for the 9 planning units
#' cd <- crop(sim_features, r)
#'
#' ## make connectivity matrix using the habitat suitability data for the
#' ## second feature to represent the planning unit conductance data
#' cm_raster <- connectivity_matrix(r, cd[[2]])
#'
#' ## plot data and matrix
#' \dontrun{
#' par(mfrow = c(1,3))
#' plot(r, main = "planning units (raster)", axes = FALSE, box = FALSE)
#' plot(cd[[2]], main = "conductivity", axes = FALSE, box = FALSE)
#' plot(clamp(raster(as.matrix(cm_raster)), lower = 1e-5, useValues = FALSE),
#'      main = "connectivity", axes = FALSE, box = FALSE)
#' }
#' # create connectivity matrix using polygon planning unit data using
#' # the habitat suitability data for the second feature to represent
#' # planning unit conductances
#' ## subset data to 9 polygons
#' ply <- sim_pu_sf[c(1:2, 10:12, 20:22), ]
#'
#' ## make connectivity matrix
#' cm_ply <- connectivity_matrix(ply, sim_features[[2]])
#'
#' ## plot data and matrix
#' \dontrun{
#' par(mfrow = c(1, 2))
#' plot(st_geometry(ply), main = "planning units (sf)")
#' plot(clamp(raster(as.matrix(cm_ply)), lower = 1e-5, useValues = FALSE),
#'      main = "connectivity", axes = FALSE, box = FALSE)
#' }
#'
#' # create connectivity matrix using habitat suitability data for each feature,
#' # this could be useful if prioritisations should spatially clump
#' # together adjacent planning units that have suitable habitat
#' # for the same species (e.g. to maintain functional connectivity)
#'
#' ## let's use the raster data for this example, and we can generate the
#' ## connectivity matrix that we would use in the prioritization by
#' ## (1) generating a connectivity matrix for each feature separately, and
#' ## and then (2) then summing the values together
#' cm_sum <- lapply(as.list(cd), connectivity_matrix, x = r) # make matrices
#' cm_sum <- Reduce("+", cm_sum) # sum matrices together
#'
#' ## plot data and matrix
#' \dontrun{
#' par(mfrow = c(1, 2))
#' plot(r, main = "planning units (raster)", axes = FALSE, box = FALSE)
#' plot(clamp(raster(as.matrix(cm_sum)), lower = 1e-5, useValues = FALSE),
#'      main = "connectivity", axes = FALSE, box = FALSE)
#' }
#'
#' ## we could take this example one step further, and use weights to indicate
#' ## relative importance of maintaining functional connectivity
#' ## for each feature (i.e. use the weighted sum instead of the sum)
#'
#' ## let's pretend that the first feature is 20 times more important
#' ## than all the other species
#' weights <- c(20, 1, 1, 1, 1)
#'
#' ## calculate connectivity matrix using weighted sum
#' cm_wsum <- lapply(as.list(cd), connectivity_matrix, x = r) # make matrices
#' cm_wsum <- Map("*", cm_wsum, weights) # multiply by weights
#' cm_wsum <- Reduce("+", cm_wsum) # sum matrices together
#'
#' ## plot data and matrix
#' \dontrun{
#' par(mfrow = c(1, 2))
#' plot(r, main = "planning units (raster)", axes = FALSE, box = FALSE)
#' plot(clamp(raster(as.matrix(cm_wsum)), lower = 1e-5, useValues = FALSE),
#'      main = "connectivity", axes = FALSE, box = FALSE)
#' }
#'
#' ## since the statistical distribution of the connectivity values
#' ## for each feature (e.g. the mean and standard deviation of the
#' ## connectivity values) are different, it might make sense -- depending
#' ## on the goal of the conservation planning exercise and the underlying
#' ## data -- to first normalize the conductance values before applying the
#' ## weights and summing the data for feature together
#'
#' ## one approach would be to linearly rescale the values between 0.01 and 1
#' ## note that we wouldn't want to rescale them between 0 and 1 since
#' ## a value of zero means that there is no connectivity at all (and
#' ## and not a relatively small amount of connectivity)
#' \dontrun{
#' ### define helper function
#' library(scales) # load scales library for rescale
#' rescale_matrix <- function(x) {x@x <- rescale(x@x, c(0.01, 1)); x}
#'
#' ### calculate functional connectivity matrix using the weighted sum of
#' ### connectivity values that have been normalized by linearly re-scaling
#' ### values
#' cm_lwsum <- lapply(as.list(cd), connectivity_matrix, x = r) # make matrices
#' cm_lwsum <- lapply(cm_lwsum, rescale_matrix) # rescale matrices to [0.01, 1]
#' cm_lwsum <- Map("*", cm_lwsum, weights) # multiply by weights
#' cm_lwsum <- Reduce("+", cm_lwsum) # sum matrices together
#' }
#'
#' ## plot data and matrix
#' \dontrun{
#' par(mfrow = c(1, 2))
#' plot(r, main = "planning units (raster)", axes = FALSE, box = FALSE)
#' plot(clamp(raster(as.matrix(cm_lwsum)), lower = 1e-5, useValues = FALSE),
#'      main = "connectivity", axes = FALSE, box = FALSE)
#' }
#'
#' ## another approach for normalizing the data could be using z-scores
#' ## note that after normalizing the data we would need to add a constant
#' ## value so that none of the connectivity values are negative
#'
#' ### define helper functions
#' zscore <- function(x) {x@x <- (x@x - mean(x@x)) / sd(x@x); x}
#' min_non_zero_value <- function(x) min(x@x)
#' add_non_zero_value <- function(x, y) {x@x <- x@x + y; x}
#'
#' ### calculate functional connectivity matrix using the weighted sum of
#' ### connectivity values that have been normalized using z-scores,
#' ### and transformed to account for negative values
#' cm_zwsum <- lapply(as.list(cd), connectivity_matrix, x = r) # make matrices
#' cm_zwsum <- lapply(cm_zwsum, zscore) # normalize using z-scores
#' min_value <- min(sapply(cm_zwsum, min_non_zero_value)) # find min value
#' min_value <- abs(min_value) + 0.01 # prepare constant for adding to matrices
#' cm_zwsum <- lapply(cm_zwsum, add_non_zero_value, min_value) # add constant
#' cm_zwsum <- Map("*", cm_zwsum, weights) # multiply by weights
#' cm_zwsum <- Reduce("+", cm_zwsum) # sum matrices together
#'
#' ## plot data and matrix
#' \dontrun{
#' par(mfrow = c(1, 2))
#' plot(r, main = "planning units (raster)", axes = FALSE, box = FALSE)
#' plot(clamp(raster(as.matrix(cm_zwsum)), lower = 1e-5, useValues = FALSE),
#'      main = "connectivity", axes = FALSE, box = FALSE)
#' }
#'
#' @aliases connectivity_matrix,Spatial,character-method connectivity_matrix,Spatial,Raster-method connectivity_matrix,Raster,Raster-method connectivity_matrix,sf,character-method connectivity_matrix,sf,Raster-method
#'
#' @export
methods::setGeneric(
  "connectivity_matrix",
  signature = methods::signature("x", "y"),
  function(x, y, ...) standardGeneric("connectivity_matrix"))

#' @name connectivity_matrix
#' @usage \S4method{connectivity_matrix}{Spatial,Raster}(x, y, ...)
#' @rdname connectivity_matrix
methods::setMethod(
  "connectivity_matrix",
  signature(x = "Spatial", y = "Raster"),
  function(x, y, ...) {
    assertthat::assert_that(inherits(x, "Spatial"))
    connectivity_matrix(sf::st_as_sf(x), y, ...)
  })

#' @name connectivity_matrix
#' @usage \S4method{connectivity_matrix}{Spatial,character}(x, y, ...)
#' @rdname connectivity_matrix
methods::setMethod(
  "connectivity_matrix",
  signature(x = "Spatial", y = "character"),
  function(x, y, ...) {
    assertthat::assert_that(inherits(x, "Spatial"))
    connectivity_matrix(sf::st_as_sf(x), y, ...)
  })

#' @name connectivity_matrix
#' @usage \S4method{connectivity_matrix}{sf,character}(x, y, ...)
#' @rdname connectivity_matrix
methods::setMethod(
  "connectivity_matrix",
  signature(x = "sf", y = "character"),
  function(x, y, ...) {
    # validate that arguments are valid
    assertthat::assert_that(inherits(x, "sf"),
      assertthat::is.string(y),
      assertthat::has_name(x, y))
    assertthat::assert_that(is.numeric(x[[y]]), assertthat::noNA(x[[y]]))
    # generate connectivity data for each pair of connected units
    bd <- matrix_to_triplet_dataframe(boundary_matrix(x))
    bd <- bd[bd[[1]] != bd[[2]], ]
    bd$x <- bd$x * ( (x[[y]][bd$i] + x[[y]][bd$j]) * 0.5)
    bd <- bd[which(bd$x > 0), ]
    # generate connectivity matrix
    Matrix::sparseMatrix(i = bd$i, j = bd$j, x = bd$x, symmetric = TRUE,
                         dims = rep(nrow(x), 2))
  })

#' @name connectivity_matrix
#' @usage \S4method{connectivity_matrix}{sf,Raster}(x, y, ...)
#' @rdname connectivity_matrix
methods::setMethod(
  "connectivity_matrix",
  signature(x = "sf", y = "Raster"),
  function(x, y, ...) {
    # assert that arguments are valid
    assertthat::assert_that(
      inherits(x, "sf"),
      inherits(y, "Raster"),
      raster::nlayers(y) == 1)
    assertthat::assert_that(
      sf::st_crs(x) == sf::st_crs(y@crs),
      intersecting_extents(x, y))
    # extract conductance values
    cv <- fast_extract(y, x, ...)
    # generate connectivity data for each pair of connected units
    bd <- matrix_to_triplet_dataframe(boundary_matrix(x))
    bd <- bd[bd[[1]] != bd[[2]], ]
    bd$x <- bd$x * ( (cv[bd$i] + cv[bd$j]) * 0.5)
    bd <- bd[which(bd$x > 0), ]
    # connectivity matrix
    Matrix::sparseMatrix(i = bd$i, j = bd$j, x = bd$x, symmetric = TRUE,
                         dims = rep(nrow(x), 2))
  })

#' @name connectivity_matrix
#' @usage \S4method{connectivity_matrix}{Raster,Raster}(x, y, ...)
#' @rdname connectivity_matrix
methods::setMethod(
  "connectivity_matrix",
  signature(x = "Raster", y = "Raster"),
  function(x, y, ...) {
    # validate that arguments are valid
    assertthat::assert_that(inherits(x, "Raster"), inherits(y, "Raster"),
      raster::nlayers(x) == 1, raster::nlayers(y) == 1,
      is_comparable_raster(x, y))
    # extract data from first bands in x and y
    x <- x[[1]]
    y <- y[[1]]
    # generate connectivity data for each pair of connected units
    bd <- matrix_to_triplet_dataframe(boundary_matrix(x))
    bd <- bd[bd[[1]] != bd[[2]], ]
    bd$x <- bd$x * ( (y[bd$i] + y[bd$j]) * 0.5)
    bd <- bd[which(bd$x > 0), ]
    # connectivity matrix
    Matrix::sparseMatrix(i = bd$i, j = bd$j, x = bd$x, symmetric = TRUE,
                         dims = rep(raster::ncell(x), 2))
  })
