# ridge logistic regression
library(glmnet)
library(pROC)
library(ResourceSelection)
library(caret)
library(ggplot2)

# check structure of data ====
data <- read.csv("C:/Users/Megan/Documents/WESTPH_STATS_TEST/final_standardized_data.csv")
str(data)

# outcome_var is binary
if(!all(data$outcome_var %in% c(0, 1))) {
  stop("The outcome_var should be binary (0 or 1).")
}

# check for missing values
if(any(is.na(data))) {
  stop("The dataset contains missing values. Please handle them before proceeding.")
}

# visualize distributions of predictors ====
visualize_distributions <- function(data) {
  # list of predictor variables
  continuous_vars <- c("P_DRT", "C_WET", "T_SUM", "T_WIN", "V_LOW")
  
  # ensure predictors are present in data frame
  data <- data %>%
    select(all_of(continuous_vars))
  
  # gather data into long format
  long_data <- data %>%
    gather(key = "variable", value = "value", all_of(continuous_vars))
  
  # create histograms for each variable
  p <- ggplot(long_data, aes(x = value)) +
    geom_histogram(bins = 30, fill = "dark green", color = "grey", alpha = 0.7) +
    facet_wrap(~ variable, scales = "free", ncol = 1) +
    theme_minimal() +
    labs(title = "Distributions of Predictor Variables",
         x = "Value",
         y = "Count")
  
  # print the plot
  print(p)
}

visualize_distributions(data)

# reproducibility seed
set.seed(42)

# splitting ====
# split into training and testing sets (75/25 split)
split <- sample.split(data$outcome_var, SplitRatio = 0.75)

# create training and testing datasets while retaining State_ID
train_data <- subset(data, split == TRUE)
test_data <- subset(data, split == FALSE)

# check dimensions of training and testing sets
dim(train_data)
dim(test_data)

# prep for ridge model
# Combine training and test data, while retaining which rows belong to which set
combined_data <- rbind(train_data, test_data)
combined_data$is_train <- c(rep(TRUE, nrow(train_data)), rep(FALSE, nrow(test_data)))

# Create the design matrix using model.matrix on the combined data
x_combined <- model.matrix(outcome_var ~ . - 1, data = combined_data)  # -1 removes the intercept

# Split back into training and test sets
x_train <- x_combined[combined_data$is_train == TRUE, ]
x_test <- x_combined[combined_data$is_train == FALSE, ]

# Ensure outcome variables are correctly split
y_train <- train_data$outcome_var
y_test <- test_data$outcome_var

# Cross-Validation to tune the regularization parameter (lambda)
cv_ridge <- cv.glmnet(x_train, y_train, family = "binomial", alpha = 0)  # alpha = 0 for Ridge

# Extract the best lambda
best_lambda_ridge <- cv_ridge$lambda.min
print(paste("Best lambda for Ridge: ", best_lambda_ridge))

# Fit the final Ridge logistic regression model using the best lambda
final_ridge_model <- glmnet(x_train, y_train, family = "binomial", lambda = best_lambda_ridge, alpha = 0)

# Predict probabilities on the test set using the Ridge logistic regression model
test_data$predicted_prob <- predict(final_ridge_model, newx = x_test, type = "response")

# Convert probabilities to class predictions (Threshold = 0.52)
test_data$predicted_class <- ifelse(test_data$predicted_prob > 0.52, 1, 0)

# evaluate model performance ====

# Predict probabilities on the test set using the Ridge logistic regression model
test_data$predicted_prob <- predict(final_ridge_model, newx = x_test, type = "response")

# convert to class predictions (threshold = 0.5)
test_data$predicted_class <- ifelse(test_data$predicted_prob > 0.52, 1, 0)

# calculate AIC for the Ridge model
# Alternative approach: focus on cross-validation error
cv_ridge$cvm[cv_ridge$lambda == best_lambda_ridge]  # Cross-validated mean squared error at best lambda

# ROC Curve and AUC
# Ensure predicted probabilities are extracted as a numeric vector
test_data$predicted_prob <- as.vector(predict(final_ridge_model, newx = x_test, type = "response"))

# Calculate ROC Curve and AUC
roc_curve <- roc(y_test, test_data$predicted_prob)
plot(roc_curve, main = "ROC Curve for Ridge Logistic Regression", col = "blue", lwd = 2)
auc_value <- auc(roc_curve)
print(paste("AUC: ", round(auc_value, 2)))


# Confusion Matrix
conf_matrix <- confusionMatrix(factor(test_data$predicted_class), factor(y_test))
print(conf_matrix)

# Hosmer-Lemeshow Test
hoslem_test <- hoslem.test(y_test, test_data$predicted_prob, g=10)
print(hoslem_test)

# Residual Plots
# Calculate residuals for the training data
train_data$predicted_prob <- as.vector(predict(final_ridge_model, newx = x_train, type = "response"))
train_data$residuals <- y_train - train_data$predicted_prob

# Plot residuals
ggplot(train_data, aes(x = train_data$predicted_prob, y = train_data$residuals)) +
  geom_point() +
  geom_smooth(method = "loess", se = FALSE) +
  labs(title = "Residuals vs Predicted Probabilities", x = "Predicted Probabilities", y = "Residuals")

# Identify Incorrectly Classified State_IDs
# Ensure predicted probabilities are extracted as a numeric vector
test_data$predicted_prob <- as.vector(predict(final_ridge_model, newx = x_test, type = "response"))

# Convert probabilities to class predictions (Threshold = 0.52)
test_data$predicted_class <- ifelse(test_data$predicted_prob > 0.52, 1, 0)

# Identify incorrectly predicted State_IDs
incorrect_predictions <- test_data %>%
  filter(predicted_class != y_test) %>%
  select(State_ID, outcome_var, predicted_class, predicted_prob)

print("Incorrectly predicted State_IDs:")
print(incorrect_predictions)

