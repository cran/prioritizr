#' @include internal.R
NULL

#' @import raster
#' @import sp
#' @useDynLib prioritizr, .registration = TRUE
NULL

#' prioritizr
#'
#' \emph{Prioritizr} is an R package for solving systematic conservation
#' planning problems. By using integer linear programming (ILP)
#' techniques, this package offers a flexible interface for creating
#' reserve selection problems that can be tailored to the specific needs of the
#' conservation planner (Rodrigues \emph{et al.} 2000; Billionnet 2013).
#' Conservation problems can be solved using a variety of commercial and
#' open-source exact algorithm solvers. In contrast to the algorithms
#' conventionally used to solve conservation problems, such as greedy
#' heuristics or simulated annealing, the exact algorithms used by
#' \emph{prioritizr} are guaranteed to find optimal solutions. This package
#' also has the functionality to read \href{http://marxan.net/}{Marxan} input
#' data (Ball \emph{et al.} 2009) and find much better solutions in a much
#' shorter period of time than Marxan  (Beyer \emph{et al.} 2016). See the
#' \href{https://github.com/prioritizr/prioritizr}{online code repository}
#' for more information.
#'
#' @details This package contains vignettes that introduce systematic
#' conservation planning and basic usage of the \emph{prioritizr} package. The
#'  supplemental
#' \href{https://github.com/prioritizr/prioritizrdata}{\emph{prioritizrdata}}
#' package contains further example datasets and worked examples. The vignettes
#' in this package are listed below.
#'
#' \describe{
#' \item{\href{https://prioritizr.github.io/prioritizr/articles/prioritizr_basics.html}{Prioritizr Basics}}{Background information
#'  on the concepts and terminology that underpin systematic conservation
#'  planning and their usage in this package.}
#' \item{\href{https://prioritizr.github.io/prioritizr/articles/quick_start.html}{Quickstart Guide}}{Short walk-through of the
#'   \emph{prioritizr} package with a simulated dataset.}
#'
#' }
#'
#' @references
#' Ball IR, Possingham HP, and Watts M (2009) \emph{Marxan and relatives:
#' Software for spatial conservation prioritisation} in Spatial conservation
#' prioritisation: Quantitative methods and computational tools. Eds Moilanen
#' A, Wilson KA, and Possingham HP. Oxford University Press, Oxford, UK.
#'
#' Beyer HL, Dujardin Y, Watts ME, and Possingham HP (2016) Solving
#' conservation planning problems with integer linear programming.
#' \emph{Ecological Modelling}, 228: 14--22.
#'
#' Billionnet A (2013) Mathematical optimization ideas for biodiversity
#' conservation. \emph{European Journal of Operational Research}, 231:
#' 514--534.
#'
#' Rodrigues AS, Cerdeira OJ, and Gaston KJ (2000) Flexibility,
#' efficiency, and accountability: adapting reserve selection algorithms to
#' more complex conservation problems. \emph{Ecography}, 23: 565--574.
#'
#' @name prioritizr
#' @docType package
NULL