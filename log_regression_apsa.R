library(dplyr)
library(caTools)
library(car)
library(caret)
library(tidyverse)
library(glmnet)
library(pROC)

# data structure ====
data <- read.csv("C:/Users/Megan/Documents/WESTPH_STATS_TEST/final_standardized_data.csv")
str(data)

# histograms: predictor distributions ====
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

# data splitting (75/25 split) ====
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

# check for multicollinearity ====
# fitting a preliminary model
prelim_model <- glm(outcome_var ~ ., data = train_data, family = binomial)

# check Variance Inflation Factor (VIF)
vif_values <- vif(prelim_model)
print(vif_values)
# vif values: t_sum 1.064125, v_low 1.024061, p_drt 1.055579, t_win 1.189052, c_wet 1.156622 

# fit regression model ====
final_model <- glm(outcome_var ~ ., data = train_data, family = binomial)
summary(final_model)

# evaluate model ====
# calculate AIC
aic_value <- AIC(final_model)
print(paste("AIC: ", round(aic_value, 2)))

# predict on test set without State_ID
test_data_no_id$predicted_prob <- predict(final_model, newdata = test_data_no_id, type = "response")
test_data_no_id$predicted_class <- ifelse(test_data_no_id$predicted_prob > 0.46, 1, 0)

# calculate odds ratios
odds_ratios <- exp(coef(final_model))
print(odds_ratios)

# calculate confidence intervals
conf_intervals <- exp(confint(final_model))
odds_ratios_with_conf <- cbind(odds_ratios, conf_intervals)
print(odds_ratios_with_conf)

# confusion matrix ====
conf_matrix <- confusionMatrix(factor(test_data_no_id$predicted_class, levels = c(0, 1)), 
                               factor(test_data$outcome_var, levels = c(0, 1)), positive = "1")

accuracy <- conf_matrix$overall['Accuracy']
sensitivity <- conf_matrix$byClass['Sensitivity']
specificity <- conf_matrix$byClass['Specificity']

print(conf_matrix)

# ROC Curve and AUC ====
roc_curve <- roc(test_data$outcome_var, test_data_no_id$predicted_prob, levels = c(0, 1))

plot(roc_curve, main = "ROC Curve", col = "dark green", lwd = 2)

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

