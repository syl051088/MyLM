#' Fit Linear Regression Model
#'
#' The `my_lm` function fits a linear regression model using the normal equations method.
#' It returns an object of class `"linearR"` containing the model fit results, including
#' coefficients, standard errors, t-statistics, p-values, residuals, fitted values, and
#' various summary statistics.
#'
#' @param formula An object of class \code{"formula"}: a symbolic description of the model to be fitted.
#' @param data A data frame containing the variables in the model.
#' @return An object of class \code{"linearR"} containing the model fit results.
#' @details The function uses the normal equations method to estimate the coefficients:
#' \deqn{\hat{\beta} = (X^\top X)^{-1} X^\top y}
#' where \eqn{X} is the design matrix and \eqn{y} is the response vector.
#' @importFrom stats model.frame .getXlevels model.matrix model.response pt
#' @examples
#' data(mtcars)
#' fit <- my_lm(mpg ~ wt + cyl, data = mtcars)
#' summary(fit)
#' @export
my_lm <- function(formula, data) {
  # Check for NULL or empty data
  if (is.null(data) || nrow(data) == 0) {
    stop("empty or NULL data")
  }

  # Check for NAs in variables used in formula
  vars <- all.vars(formula)
  for(var in vars) {
    if(!var %in% names(data)) {
      stop(paste("variable", var, "not found in data"))
    }
    if(any(is.na(data[[var]]))) {
      stop("missing values in model frame")
    }
  }

  # Extract model frame
  tryCatch({
    mf <- model.frame(formula, data)
  }, error = function(e) {
    stop("error in model frame: ", e$message)
  })

  # Additional check for missing values in model frame
  if (anyNA(mf)) {
    stop("missing values in model frame")
  }

  # Extract terms and xlevels
  terms <- attr(mf, "terms")
  xlevels <- .getXlevels(terms, mf)

  # Extract X matrix and y vector
  X <- model.matrix(terms, mf)
  y <- model.response(mf)

  # Get dimensions
  n <- nrow(X)
  p <- ncol(X)

  # Check for insufficient degrees of freedom
  if (n <= p) {
    stop("insufficient degrees of freedom")
  }

  # Calculate coefficients
  XtX <- t(X) %*% X
  tryCatch({
    XtX_inv <- solve(XtX)
  }, error = function(e) {
    stop("system is exactly singular")
  })
  Xty <- t(X) %*% y
  coefficients <- drop(XtX_inv %*% Xty)  # Use drop() to convert to vector
  names(coefficients) <- colnames(X)      # Add names from X matrix

  # Calculate fitted values and residuals
  fitted <- drop(X %*% coefficients)
  residuals <- drop(y - fitted)

  # Calculate standard errors
  sigma2 <- sum(residuals^2) / (n - p)
  vcov <- sigma2 * XtX_inv
  se <- drop(sqrt(diag(vcov)))
  names(se) <- names(coefficients)        # Add names to standard errors

  # Calculate t-statistics and p-values
  tstat <- coefficients / se
  pval <- 2 * pt(abs(tstat), df = n - p, lower.tail = FALSE)
  names(tstat) <- names(pval) <- names(coefficients)  # Add names to t-stats and p-values

  # Calculate R-squared
  r_squared <- 1 - sum(residuals^2) / sum((y - mean(y))^2)
  adj_r_squared <- 1 - (1 - r_squared) * (n - 1) / (n - p)

  # Return results
  structure(list(
    coefficients = coefficients,
    se = se,
    tstat = tstat,
    pval = pval,
    residuals = residuals,
    fitted = fitted,
    r.squared = r_squared,
    adj.r.squared = adj_r_squared,
    formula = formula,
    terms = terms,
    xlevels = xlevels,
    X = X,
    y = y,
    n = n,
    p = p,
    XtX_inv = XtX_inv,
    call = match.call(),
    vcov = vcov,
    sigma2 = sigma2,
    df.residual = n - p
  ), class = "linearR")
}

#' Summary Method for linearR Objects
#'
#' Provides a detailed summary of a `linearR` object, including coefficients with standard errors, t-values, p-values, and model statistics.
#'
#' @param object An object of class \code{"linearR"}.
#' @param ... Additional arguments (currently not used).
#' @return An object of class \code{"summary_linearR"} containing the summary information.
#' @details The summary includes:
#' \describe{
#'   \item{\code{call}}{The matched call.}
#'   \item{\code{coefficients}}{A table with estimates, standard errors, t-values, and p-values.}
#'   \item{\code{r.squared}}{Multiple R-squared statistic.}
#'   \item{\code{adj.r.squared}}{Adjusted R-squared statistic.}
#'   \item{\code{sigma}}{Residual standard error estimate.}
#'   \item{\code{df}}{Degrees of freedom used in the model.}
#' }
#' @examples
#' data(mtcars)
#' fit <- my_lm(mpg ~ wt + cyl, data = mtcars)
#' summary_linearR(fit)
#' @export
summary_linearR <- function(object, ...) {
  # Create coefficients table
  coef_table <- data.frame(
    Estimate = object$coefficients,
    "Std. Error" = object$se,
    "t value" = object$tstat,
    "Pr(>|t|)" = object$pval
  )

  # Convert to matrix to match lm output
  coef_matrix <- as.matrix(coef_table)
  rownames(coef_matrix) <- names(object$coefficients)

  structure(list(
    call = object$call,
    coefficients = coef_matrix,
    r.squared = object$r.squared,
    adj.r.squared = object$adj.r.squared,
    sigma = sqrt(object$sigma2),
    df = c(object$p - 1, object$df.residual)
  ), class = "summary_linearR")
}

#' Print Method for summary_linearR Objects
#'
#' Prints the summary of a `linearR` object generated by \code{\link{summary_linearR}}.
#'
#' @param x An object of class \code{"summary_linearR"}.
#' @param ... Additional arguments (currently not used).
#' @return Invisibly returns \code{x}.
#' @importFrom stats printCoefmat
#' @examples
#' data(mtcars)
#' fit <- my_lm(mpg ~ wt + cyl, data = mtcars)
#' summary_fit <- summary_linearR(fit)
#' print_summary_linearR(summary_fit)
#' @export
print_summary_linearR <- function(x, ...) {
  cat("\nCall:\n")
  print(x$call)

  cat("\nResiduals:\n")
  cat("Degrees of Freedom:", x$df[2], "\n")

  cat("\nCoefficients:\n")
  printCoefmat(x$coefficients, P.values = TRUE, has.Pvalue = TRUE)

  cat("\nResidual standard error:", format(x$sigma, digits = 4),
      "on", x$df[2], "degrees of freedom")
  cat("\nMultiple R-squared:", format(x$r.squared, digits = 4))
  cat("\nAdjusted R-squared:", format(x$adj.r.squared, digits = 4))

  invisible(x)
}

#' Predict Method for linearR Objects
#'
#' Generates predictions from a `linearR` object, optionally with confidence or prediction intervals.
#'
#' @param object An object of class \code{"linearR"}.
#' @param newdata Optional data frame for which to make predictions. If omitted, the fitted values are used.
#' @param interval Type of interval calculation. Options are \code{"none"}, \code{"confidence"}, or \code{"prediction"}.
#' @param level Confidence level for the intervals (default is 0.95).
#' @param ... Additional arguments (currently not used).
#' @return A vector of predicted values or a matrix with columns for the fit and the lower and upper bounds of the intervals.
#' @details
#' - If \code{interval = "none"}, returns the predicted values.
#' - If \code{interval = "confidence"}, returns confidence intervals for the mean response.
#' - If \code{interval = "prediction"}, returns prediction intervals for a new observation.
#' @importFrom stats terms delete.response model.frame model.matrix qt
#' @examples
#' data(mtcars)
#' fit <- my_lm(mpg ~ wt + cyl, data = mtcars)
#' new_data <- data.frame(wt = c(2.5, 3.0), cyl = c(6, 8))
#' predict_linearR(fit, newdata = new_data, interval = "confidence")
#' @export
predict_linearR <- function(object, newdata = NULL,
                            interval = c("none", "confidence", "prediction"),
                            level = 0.95, ...) {
  interval <- match.arg(interval)

  if (is.null(newdata)) {
    X <- object$X
    pred <- object$fitted
  } else {
    # Check for missing values in newdata
    if (any(sapply(newdata, is.na))) {
      stop("missing values in 'newdata'")
    }

    # Create model matrix from newdata
    tt <- terms(object$formula)
    Terms <- delete.response(tt)
    tryCatch({
      mf <- model.frame(Terms, newdata, xlev = object$xlevels)
      X <- model.matrix(Terms, mf)
    }, error = function(e) {
      stop("variables in 'newdata' do not match the model")
    })

    pred <- as.numeric(X %*% object$coefficients)
  }

  if (interval == "none") {
    return(pred)
  }

  # Calculate standard errors for intervals
  alpha <- 1 - level
  t.val <- qt(1 - alpha/2, object$df.residual)

  if (interval == "confidence") {
    XtXinv <- solve(t(object$X) %*% object$X)
    se.fit <- sqrt(object$sigma2 * diag(X %*% XtXinv %*% t(X)))
    margin <- t.val * se.fit
  } else {  # prediction interval
    XtXinv <- solve(t(object$X) %*% object$X)
    se.fit <- sqrt(object$sigma2 * (1 + diag(X %*% XtXinv %*% t(X))))
    margin <- t.val * se.fit
  }

  cbind(fit = pred,
        lwr = pred - margin,
        upr = pred + margin)
}
