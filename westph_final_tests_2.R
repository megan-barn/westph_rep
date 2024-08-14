library(dplyr)
library(caTools)
library(car)
library(caret)
library(tidyverse)
library(ROSE)
library(glmnet)
library(pROC)

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

# remove State_ID from train_data and test_data for model fitting
train_data <- train_data %>% select(-State_ID)
test_data_no_id <- test_data %>% select(-State_ID)

# check dimensions of training and testing sets
dim(train_data)
dim(test_data_no_id)

# further prepare split data ====
x_train <- model.matrix(outcome_var ~ ., data = train_data)[, -1]  # Create matrix of predictors
y_train <- train_data$outcome_var  # Outcome variable

# tune regularization parameter (lambda)
cv_ridge <- cv.glmnet(x_train, y_train, family = "binomial", alpha = 0)  # alpha = 0 for Ridge

# extract the best lambda value
best_lambda_ridge <- cv_ridge$lambda.min
print(paste("Best lambda for Ridge: ", best_lambda_ridge))


# check for multicollinearity ====
# fitting a preliminary model
prelim_model <- glm(outcome_var ~ ., data = train_data, family = binomial)

# check Variance Inflation Factor (VIF)
vif_values <- vif(prelim_model)
print(vif_values)
# vif values: t_sum 1.064125, v_low 1.024061, p_drt 1.055579, t_win 1.189052, c_wet 1.156622 

# VIF > 5 indicates potential multicollinearity
if(any(vif_values > 5)) {
  warning("Some predictor variables have high VIF values, indicating multicollinearity.")
}

# fit ridge regression model ====
final_ridge_model <- glmnet(x_train, y_train, family = "binomial", lambda = best_lambda_ridge, alpha = 0)

# prepare test set predictors
x_test <- model.matrix(outcome_var ~ ., data = test_data_no_id)[, -1]

# predict on test set
test_data_no_id$predicted_prob <- predict(final_ridge_model, newx = x_test, type = "response")

# probabilities class predictions using threshold 0.5
test_data_no_id$predicted_class <- ifelse(test_data_no_id$predicted_prob > 0.5, 1, 0)


# fit regression model ====
final_model <- glm(outcome_var ~ ., data = train_data, family = binomial)
summary(final_model)

# calculate AIC
aic_value <- AIC(final_model)
print(paste("AIC: ", round(aic_value, 2)))



# evaluate significance of predictors ====
significance <- summary(final_ridge_model)$coefficients
print(significance)

# predict on test set without State_ID
test_data_no_id$predicted_prob <- predict(final_model, newdata = test_data_no_id, type = "response")
test_data_no_id$predicted_class <- ifelse(test_data_no_id$predicted_prob > 0.46, 1, 0)

# confusion matrix
conf_matrix <- confusionMatrix(factor(test_data_no_id$predicted_class), factor(test_data$outcome_var))

# model accuracy, sensitivity, and specificity
accuracy <- conf_matrix$overall['Accuracy']
sensitivity <- conf_matrix$byClass['Sensitivity']
specificity <- conf_matrix$byClass['Specificity']

print(paste("Accuracy: ", round(accuracy, 2)))
print(paste("Sensitivity: ", round(sensitivity, 2)))
print(paste("Specificity: ", round(specificity, 2)))

# confusion matrix details
print(conf_matrix)

# ROC Curve and AUC
roc_curve <- roc(test_data$outcome_var, test_data_no_id$predicted_prob)

# plot ROC curve
plot(roc_curve, main = "ROC Curve", col = "dark green", lwd = 2)

# print AUC value
auc_value <- auc(roc_curve)
print(paste("AUC: ", round(auc_value, 2)))

# identify incorrectly predicted State_IDs ====
# predict on test set without State_ID
test_data_no_id$predicted_prob <- predict(final_model, newdata = test_data_no_id, type = "response")
test_data_no_id$predicted_class <- ifelse(test_data_no_id$predicted_prob > 0.46, 1, 0)

# add predicted columns back to test_data
test_data <- test_data %>%
  mutate(predicted_prob = test_data_no_id$predicted_prob,
         predicted_class = test_data_no_id$predicted_class)

# identify incorrectly predicted State_IDs
incorrect_predictions <- test_data %>%
  filter(predicted_class != outcome_var) %>%
  select(State_ID, outcome_var, predicted_class, predicted_prob)

print("Incorrectly predicted State_IDs:")
print(incorrect_predictions)


