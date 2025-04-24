# Load necessary libraries
library(dplyr)
library(ggplot2)
library(stringr)
library(lubridate)
library(stringr)

# Load raw CSV and clean header
raw_data <- read.csv("messy_ice_detention.csv", header = FALSE)
head(raw_data,10)
# Remove initial meta rows and set column names
data_clean <- raw_data[-c(1:6), ]
colnames(data_clean) <- as.character(unlist(data_clean[1, ]))
data_clean <- data_clean[-1, ]
rownames(data_clean) <- NULL
head(data_clean)
check_problematic_rows <- function(data) {
  data %>%
    mutate(
      # Clean the text columns to UTF-8 encoding
      Name = iconv(Name, from = "", to = "UTF-8", sub = ""),
      City = iconv(City, from = "", to = "UTF-8", sub = ""),
      State = iconv(State, from = "", to = "UTF-8", sub = ""),
      
      # Combine all issues into a single column 'issue'
      issue = case_when(
        # Special character issues
        str_detect(Name, "[^a-zA-Z0-9\\s]") ~ "Special char in Name",
        str_detect(City, "[^a-zA-Z0-9\\s]") ~ "Special char in City",
        str_detect(State, "[^a-zA-Z0-9\\s]") ~ "Special char in State",
        
        # Missing or invalid values issues
        is.na(Name) | str_trim(Name) == "" | tolower(str_trim(Name)) %in% c("n/a", "null") ~ "Missing/Invalid Name",
        is.na(City) | str_trim(City) == "" | tolower(str_trim(City)) %in% c("n/a", "null") ~ "Missing/Invalid City",
        is.na(State) | str_trim(State) == "" | tolower(str_trim(State)) %in% c("n/a", "null") ~ "Missing/Invalid State",
        
        TRUE ~ NA_character_ # Return NA if no issue
      )
    ) %>%
    # Filter rows where there is any issue
    filter(!is.na(issue))
}



problematic_rows <- check_problematic_rows(data_clean)

# View
problematic_rows
data_clean <- data_clean %>%
    mutate(
    Name = Name %>%
      str_replace_all("[^a-zA-Z0-9\\s\\(\\)-]", "") %>%  # Remove unwanted special characters
      str_replace_all("\\([^\\)]*$", "") %>%             # Remove unmatched opening parenthesis at end
      str_replace_all("^[^\\(]*\\)", "") %>%             # Remove unmatched closing parenthesis at beginning
      str_squish(),                                       # Clean up extra spaces
    
    City = City %>%
      str_replace_all("[^a-zA-Z0-9\\s\\(\\)-]", "") %>%  # Remove unwanted special characters
      str_replace_all("^([^\\)]*)\\(", "\\1") %>%             # Remove unmatched opening parenthesis at end
      str_replace_all("\\)([^\\(]*)$", "\\1") %>%             # Remove unmatched closing parenthesis at beginning
      str_squish(),                                       # Clean up extra spaces
      
    State = State %>%
      str_replace_all("[^a-zA-Z0-9\\s\\(\\)-]", "") %>%  # Remove unwanted special characters
      str_replace_all("^([^\\)]*)\\(", "\\1") %>%             # Remove unmatched opening parenthesis at end
      str_replace_all("\\)([^\\(]*)$", "\\1") %>%             # Remove unmatched closing parenthesis at beginning
      str_squish()
  )
data_clean
problematic_rows <- check_problematic_rows(data_clean)

# View
problematic_rows
check_missing_or_invalid <- function(df, column_name) {
  col <- df[[column_name]]
  
  invalid_indices <- which(
    is.na(col) |
    col == "" |
    str_trim(col) == "" |
    tolower(str_trim(col)) %in% c("n/a", "na", "null")
  )
  
  return(df[invalid_indices, ])
}
check_missing_or_invalid(data_clean, "Name")
data_clean <- data_clean %>%
  mutate(Name = case_when(
    City == "ELK RIVER" & State == "MN" & (is.na(Name) | str_trim(Name) == "") ~ "Sherburne County Jail",
    City == "DOVER" & State == "NH" & (is.na(Name) | str_trim(Name) == "") ~ "Strafford County Corrections",
    TRUE ~ Name
  ))
check_missing_or_invalid(data_clean, "Name")
check_missing_or_invalid(data_clean, "City")

data_clean <- data_clean %>%
  mutate(City = case_when(
    Name == "GEAUGA COUNTY JAIL" & State == "OH" & (is.na(City) | str_trim(City) == "") ~ "CHARDON",
    TRUE ~ City
  ))
check_missing_or_invalid(data_clean, "City")

check_missing_or_invalid(data_clean, "State")

data_clean <- data_clean %>%
  mutate(State = case_when(
    Name == "ATLANTAUSPEN" & (is.na(State) | str_trim(State) == "") ~ "GA",
    Name == "LA SALLE COUNTY REGIONAL DETENTION CENTER" & (is.na(State) | str_trim(State) == "") ~ "TX",
    TRUE ~ State
  ))

check_missing_or_invalid(data_clean, "State")
summary(data_clean)
# Convert population columns to numeric
data_clean <- data_clean %>%
  mutate(
    `Level A` = as.numeric(`Level A`),
    `Level B` = as.numeric(`Level B`),
    `Level C` = as.numeric(`Level C`),
    `Level D` = as.numeric(`Level D`)
  )
summary(data_clean)
# Handle inspection date format
data_clean <- data_clean %>%
  mutate(
    `Last Inspection End Date` = case_when(
      tolower(trimws(`Last Inspection End Date`)) %in% c("na", "n/a", "", "null") ~ NA_character_,
      TRUE ~ str_trim(`Last Inspection End Date`)
    )
  ) %>%
  mutate(
    `Last Inspection End Date` = case_when(
      grepl("^\\d{1,2}/\\d{1,2}/\\d{4}$", `Last Inspection End Date`) ~
        as.character(mdy(`Last Inspection End Date`)),
      grepl("^\\d{5}$", `Last Inspection End Date`) ~
        as.character(as.Date(as.numeric(`Last Inspection End Date`), origin = "1899-12-30")),
      TRUE ~ `Last Inspection End Date`
    ),
    `Last Inspection End Date` = as.Date(`Last Inspection End Date`)
  )
data_clean
data_clean <- data_clean %>%
  mutate(`Total Population` = `Level A` + `Level B` + `Level C` + `Level D`)
top_10_facilities <- data_clean %>%
  arrange(desc(`Total Population`)) %>%
  slice(1:10)

top_10_facilities

ggplot(top_10_facilities, aes(x = reorder(Name, `Total Population`), y = `Total Population`)) +
  geom_bar(stat = "identity", fill = "steelblue") +  # Bar chart
  coord_flip() +  # Flip for better readability
  geom_text(aes(label = scales::comma(`Total Population`)), hjust = 1.1, size = 3) +  # Add population as text labels
  labs(
    title = "Top 10 Detention Facilities by Total Population",  # Title
    x = NULL,  # Remove x-axis label
    y = "Total Population"
  ) +
  theme_bw() +  # White background
  theme(
    axis.text.x = element_text(size = 10),  # Font size for x-axis
    axis.text.y = element_text(size = 10),  # Font size for y-axis
    plot.title = element_text(size = 16, face = "bold", hjust = 0.5),  # Center and enlarge title
    plot.margin = margin(10, 10, 30, 10)  # Increase bottom margin to fit title
  )

ggsave("top_10_detention_facilities.png", width = 10, height = 6)
