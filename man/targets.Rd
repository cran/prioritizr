% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/targets.R
\name{targets}
\alias{targets}
\title{Add representation targets}
\description{
Targets are used to specify the minimum amount or proportion of a feature's
distribution that should (ideally) be covered (represented) by a solution.
}
\details{
\strong{Please note that most objectives require targets, and attempting
to solve a problem that requires targets will throw an error.}

The following functions can be used to specify targets for a
conservation planning \code{\link[=problem]{problem()}}:

\describe{

\item{\code{\link[=add_relative_targets]{add_relative_targets()}}}{Set targets as a proportion
(between 0 and 1) of the total amount of each feature in the
the study area.}

\item{\code{\link[=add_absolute_targets]{add_absolute_targets()}}}{Set targets that denote the
minimum amount of each feature required in the prioritization.}

\item{\code{\link[=add_loglinear_targets]{add_loglinear_targets()}}}{Set targets as a proportion
(between 0 and 1) that are calculated using log-linear interpolation.}

\item{\code{\link[=add_manual_targets]{add_manual_targets()}}}{Set targets manually.}

}
}
\examples{
\dontrun{
# load data
sim_pu_raster <- get_sim_pu_raster()
sim_features <- get_sim_features()

# create base problem
p <-
  problem(sim_pu_raster, sim_features) \%>\%
  add_min_set_objective() \%>\%
  add_binary_decisions() \%>\%
  add_default_solver(verbose = FALSE)

# create problem with added relative targets
p1 <- p \%>\% add_relative_targets(0.1)

# create problem with added absolute targets
p2 <- p \%>\% add_absolute_targets(3)

# create problem with added loglinear targets
p3 <- p \%>\% add_loglinear_targets(10, 0.9, 100, 0.2)

# create problem with manual targets that equate to 10\% relative targets
targs <- data.frame(
  feature = names(sim_features),
  target = 0.1,
  type = "relative"
)

p4 <- p \%>\% add_manual_targets(targs)

# solve problem
s <- c(solve(p1), solve(p2), solve(p3), solve(p4))
names(s) <- c(
  "relative targets", "absolute targets", "loglinear targets",
  "manual targets"
)
# plot solution
plot(s, axes = FALSE)
}
}
\seealso{
Other overviews: 
\code{\link{constraints}},
\code{\link{decisions}},
\code{\link{importance}},
\code{\link{objectives}},
\code{\link{penalties}},
\code{\link{portfolios}},
\code{\link{solvers}},
\code{\link{summaries}}
}
\concept{overviews}
