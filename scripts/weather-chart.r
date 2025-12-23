library(tidyverse)
library(ggplot2)

setwd('C:/Users/tygon804.stu/Documents/FCOR599/Scripts')

weather_data <- read_csv("../Data/KamloopsWeather/KamloopsA19812010.csv")
weather_data$month <- factor(weather_data$month, levels = weather_data$month)


ggplot(weather_data, aes(x = month)) +
  # Bar chart for precipitation
  geom_bar(aes(y = precipitation_mm, fill = "Precipitation"), 
           stat = "identity") +
  
  # Line and point chart for sunlight (scaled)
  geom_line(aes(y = bright_sunlight_hr / 6, colour = "Sunlight", group = 1), 
            size = 1) +
  geom_point(aes(y = bright_sunlight_hr / 6, colour = "Sunlight", group = 1), 
             size = 2) +
  
  # Dual y-axis
  scale_y_continuous(
    name = "Precipitation (mm)",
    sec.axis = sec_axis(~ . * 6, name = "Bright Sunlight (hrs)")
  ) +
  
  # Manual colours for better distinction
  scale_fill_manual(name = "", values = c("Precipitation" = "#1f77b4")) +
  scale_colour_manual(name = "", values = c("Sunlight" = "#ff7f0e")) +
  
  # Labels and theme
  labs(
    title = "Kamloops Sunshine and Precipitation (1981–2010)",
    x = "Month",
    y = "Precipitation (mm)"
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom"
  )


#ggplot(weather_data, aes(x = month)) +
#  geom_bar(aes(y = precipitation_mm, fill = 'Precipitation'), stat = 'identity') +
###  geom_point(aes(y = bright_sunlight_hr / 6, group = 1, colour = 'Sunlight')) +
#  geom_line(aes(y = bright_sunlight_hr / 6,  group = 1, colour = 'Sunlight')) +
#  scale_y_continuous(name = "Precipitation (mm)",
#                     sec.axis = sec_axis(~ . * 6, name="Bright Sunlight (hrs)")) +
#  labs(title= "Kamloops Sunshine and Precipitation for 1981 to 2010 ", 
#       x="Month",y="Precipitation (mm)")+
#  theme_bw()

