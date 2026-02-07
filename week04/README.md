# Severe Winter Weather Impact Analysis: Washington University in St. Louis – January 2026

## Overview
This project analyzes the impact of severe winter weather conditions on university operations during January 2026, implemented using Python and Snowflake.

## Enrollment Data
Student enrollment data was collected by scraping publicly available HTML pages from official university websites using BeautifulSoup.

## Weather Data
Daily weather data was retrieved via the Open-Meteo Archive API, including:
- Minimum daily temperature (°C)
- Daily snowfall accumulation (mm)

## Severe Winter Weather Classification
A day is classified as severe winter weather if either condition is met:
- Minimum temperature ≤ -7°C (approximately 20°F), OR
- Snowfall ≥ 10 mm

This threshold reflects conditions likely to disrupt campus operations and student mobility.

## Impact Metric
The total number of students impacted by severe weather is approximated using:

```
Student-Days Impacted = (Number of enrolled students) × (Number of severe weather days)
```

## Output
The final result contains one row per university with the following attributes:
- University name
- State
- Number of students enrolled
- List of severe weather days
- Total student-days impacted