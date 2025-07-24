
**********************************************************
*This files solves the Task 1 given by the PREDOC website, available online at predoc.org.
**********************************************************


************************************************************
*This sample data task will use resource-level scheduled output data from the Electricity Reliability Council of Texas (ERCOT). 
************************************************************

import delimited "/Users/vishakhasingla/Desktop/predoc/ercot task/Data/ercot_resource_output.csv", clear

describe
su

*there are 5 variables and 3,008,438 observations in this dataset

*checking for missing or duplicate values 
count if missing(sced_time_stamp, qse ,resource_name ,telemetered_net_output ,resource_status)
duplicates report

*there are no missing values or duplicates

*1.
ssc install distinct
distinct resource_name
distinct qse

*there are 1121 distinct values of the resource name variable and 194 distinct values of the qse variable.

*2.
*In ERCOT, a QSE (Qualified Scheduling Entity) is a company that helps power plants and electricity buyers take part in the Texas electricity market. It handles tasks like sending schedules to ERCOT, managing energy sales, and making sure power gets delivered when promised.

*3. 

*to count the number of unique QSE/resource name pairs
egen pair = group(qse resource_name)
distinct pair
*there are 1127 distinct qse/resource_name pairs

*(a)
*Yes, many QSEs manage multiple unique resource names. This indicates that QSEs act as central coordinators for several power plants or generators. A single QSE typically represents many resources in the ERCOT market, handling their energy scheduling and dispatch.

contract qse resource_name

bysort qse (resource_name): gen resource_count = _N

* Keep only one record per QSE with their total resource count
bysort qse (resource_count): keep if _n == 1

* Sort and list the 10 largest QSEs
gsort -resource_count
list qse resource_count in 1/10

*The top 10 highest frequency QSEs are:
* +-------------------+
*     |    qse   resour~t |
*    |-------------------|
*  1. | QTENSK        173 |
*  2. |  QLUMN         75 |
*  3. | QNRGTX         50 |
*  4. |  QCALP         44 |
*  5. |  QECNR         40 |
*     |-------------------|
*  6. |   QAEN         34 |
*  7. |  QLCRA         32 |
*  8. |  QCPSE         25 |
*  9. | QTEN23         24 |
* 10. | QSHEL2         22 |
*     +-------------------+

*(b)
*Yes, a single resource_name can be paired to more than one QSE over time. 

import delimited "/Users/vishakhasingla/Desktop/predoc/ercot task/Data/ercot_resource_output.csv", clear
*to see patterns over time, we will first sort the dataset using the resource_name variable to see how the QSEs change
sort resource_name
duplicates drop qse resource_name, force

* For each plant (resource_name), count how many different companies (QSEs) it worked with
bysort resource_name (qse): gen qse_count = _N

* Keep only one row per plant to store its total count
bysort resource_name (qse_count): keep if _n == 1
count if qse_count > 1
list if qse_count > 1
*Thus, 6 resource names are connected to more than one QSE. The overarching pattern over time is that all these 6 resource names switched from QENEL5 QSE to another QENEL QSE soon after a day/few days, possibly because of change in ownership or better results with the new QSE.

*4.

import delimited "/Users/vishakhasingla/Desktop/predoc/ercot task/Data/ercot_resource_types.csv", varnames(1) clear 

*there are 2 variables and 1,121 observations in this dataset

describe
duplicates report
count if missing(resource_name, resource_type)

*there are no duplicates but there are 4 missing values in the resource_type variable.

*(a)
distinct resource_type if !missing(resource_type)
*the resource_type variable takes 15 unique, non missing values. 

*the definitions are probably as follows:

*DSL – Diesel-fired generators 
*WIND – Wind turbines, a major renewable resource in ERCOT.
*HYDRO – Conventional hydroelectric generation.
*NUC – Nuclear power generation, e.g., South Texas Project.
*RENEW – Catch-all for renewable sources not individually categorized (e.g., biomass).

*(b)

*to check for empty strings in the resource_type variable column
gen is_blank = trim(resource_type) == ""
count if is_blank

*there are 4 empty strings in the resource_type column. the resource names missing their resource types are:
list resource_name if is_blank

*      |   resource_name |
*      |-----------------|
* 342. | GALLOWAY_SOLAR1 |
* 712. | ROSELAND_SOLAR3 |
* 792. | SSPURTWO_WIND_1 |
* 815. |  SWEETWN2_WND24 |
*      +-----------------+

*Filling the first 2 empty strings with PVGR for photovoltaic solar energy generation and the last 2 with WIND for wind turbine energy generation.
replace resource_type = "PVGR" in 342
replace resource_type = "PVGR" in 712
replace resource_type = "WIND" in 792
replace resource_type = "WIND" in 815

drop is_blank

save "/Users/vishakhasingla/Desktop/predoc/ercot task/edited data/ercot_type_edited", replace

*5.

*making a fuel type variable using the resource type variable and the list provided

gen fuel_type = ""

replace fuel_type = "Other" if inlist(resource_type, "DSL", "PWRSTR", "HYDRO", "RENEW")
replace fuel_type = "Natural Gas" if inlist(resource_type, "SCGT90", "CCGT90", "SCLE90", "GSREH", "CCLE90", "GSSUP", "GSNONR")
replace fuel_type = "Wind"        if resource_type == "WIND"
replace fuel_type = "Solar"       if resource_type == "PVGR"
replace fuel_type = "Coal"        if resource_type == "CLLIG"
replace fuel_type = "Nuclear"     if resource_type == "NUC"

save "/Users/vishakhasingla/Desktop/predoc/ercot task/edited data/ercot_type_edited", replace

*merging the 2 datasets using a many-one merge

import delimited "/Users/vishakhasingla/Desktop/predoc/ercot task/Data/ercot_resource_output.csv", clear

merge m:1 resource_name using "/Users/vishakhasingla/Desktop/predoc/ercot task/edited data/ercot_type_edited"

tab _merge
*all observations have been matched correctly.
drop _merge

save "/Users/vishakhasingla/Desktop/predoc/ercot task/edited data/merged_data", replace

*6.

use "/Users/vishakhasingla/Desktop/predoc/ercot task/edited data/merged_data", clear

*formating the sced_time_stamp variable
gen double datetime = clock(sced_time_stamp, "MDYhm")
format datetime %tc
gen date = dofc(datetime)
format date %td
gen hour = hh(datetime)

*(a)
collapse (sum) telemetered_net_output, by(date)

twoway (line telemetered_net_output date), title("Total Output by Day") xtitle("Date") ytitle("Total Output (MW)") graphregion(color(white))

*(b)

use "/Users/vishakhasingla/Desktop/predoc/ercot task/edited data/merged_data", clear

gen double datetime = clock(sced_time_stamp, "MDYhm")
format datetime %tc
gen hour = hh(datetime)

collapse (sum) telemetered_net_output, by(hour)

twoway (bar telemetered_net_output hour), title("Total Output by Hour of Day") xtitle("Hour (0–23)") ytitle("Total Output (MW)") graphregion(color(white))

*(c)

use "/Users/vishakhasingla/Desktop/predoc/ercot task/edited data/merged_data", clear

gen double datetime = clock(sced_time_stamp, "MDYhm")
format datetime %tc
gen hour = hh(datetime)

collapse (sum) telemetered_net_output, by(hour fuel_type)

	
graph bar telemetered_net_output, over(hour, label(nolabel)) over(fuel_type, gap(10)) title("Output by Hour and Fuel Type") ytitle("Total Output (MW)") graphregion(color(white))

*Patterns in the data.

*In plot (a), where output is summed by day, we observe clear variability in total generation across different days. Some days show significant peaks in output, notably around early February, which might reflect spikes in electricity demand or increased supply availability. There are also noticeable dips, especially in the days following early February, which could be due to factors such as reduced demand (possibly on weekends), unfavorable weather conditions affecting renewable sources, or scheduled maintenance on generating units. 

*Plot (b), which presents output summed by hour of day (0–23), reveals a classic daily load curve. Output is at its lowest during the early morning hours between midnight and 4 AM, gradually rising as the morning progresses. A steep increase begins around 5 or 6 AM, with a sustained peak between 8 AM and noon, corresponding to the start of typical working hours. There's another peak in the evening hours from around 5 PM to 8 PM, likely reflecting residential electricity use as people return home. This pattern then declines late at night, showing how demand shapes generation patterns throughout the day.

*In plot (c), where output is summed by both hour of day and fuel type, the roles of different fuel sources in meeting demand become clearer. Coal and nuclear exhibit relatively constant output throughout the day, indicative of their use as baseload generators. In contrast, natural gas shows marked increases during morning and evening peaks, suggesting its role as a flexible, load-following source that adjusts to short-term demand fluctuations. Solar generation rises sharply during mid-day hours, peaking between 10 AM and 2 PM, and falling to zero during nighttime—reflecting the availability of sunlight. Wind output tends to increase during the late evening and early morning hours, consistent with typical wind patterns. Fuel types categorized as "Other" contribute marginally. Together, these plots reflect a grid that relies on a balanced mix of stable and variable generation sources to meet hourly and daily electricity needs.

*7.

*The data in 6(a) does not appear stationary and appears to have some periodicity, as the output fluctuates from day to day. 

use "/Users/vishakhasingla/Desktop/predoc/ercot task/edited data/merged_data", clear

* Create daily date variable
gen double datetime = clock(sced_time_stamp, "MDYhm")
format datetime %tc
gen date = dofc(datetime)
format date %td
gen hour = hh(datetime)

collapse (sum) telemetered_net_output, by(date)

tsset date

*Unit root test- ADF test
dfuller telemetered_net_output

*In this case, the test statistic is -2.138, which is higher (less negative) than the 5% critical value of -2.983. Additionally, the MacKinnon approximate p-value is 0.2296, which is well above the conventional significance threshold of 0.05. Together, these indicate that we fail to reject the null hypothesis of a unit root. In simpler terms, this suggests that the output series behaves like a random walk and is non-stationary, meaning its statistical properties—such as mean and variance—change over time. 

*calculating and plotting the first difference fo the output
gen d_output = D.telemetered_net_output

twoway (line d_output date),title("First Difference of Total Output by Day") ytitle("Δ Output (MW)") xtitle("Date") graphregion(color(white))

dfuller d_output

*The test statistic is -3.635, which is more negative than the 5% critical value of -2.986, and the p-value is 0.0051—well below the conventional threshold of 0.05. This allows us to reject the null hypothesis of a unit root and conclude that the differenced series is stationary. In other words, while the original output data showed signs of non-stationarity, its first difference does not, suggesting that the data is integrated of order one, I(1).

*8.

use "/Users/vishakhasingla/Desktop/predoc/ercot task/edited data/merged_data", clear

*hourly timestamp
gen double hourly_time = floor(clock(sced_time_stamp, "MDYhm") / 3600000) * 3600000
format hourly_time %tc

collapse (sum) telemetered_net_output, by(hourly_time)

*creating time index
gen t = _n

*AR(3) model
tsset t
arima telemetered_net_output, ar(1/3)

*The AR(3) model for hourly electricity output indicates a strong autoregressive structure in the data. All three lag terms are statistically significant at the 1% level. The first lag has a positive and large coefficient (2.215), suggesting that current output is heavily influenced by the immediately preceding hour. The second lag has a large negative coefficient (−1.747), and the third lag is again positive (0.512). This alternating sign pattern suggests cyclical behavior in electricity output. The overall model fit is strong, as indicated by the highly significant Wald chi-squared statistic (p < 0.001). However, the very high coefficient for the first lag and the fact that the sum of the AR coefficients is close to 1 may suggest persistent autocorrelation, meaning shocks to the system have a lasting effect.  If residuals still show significant autocorrelation, the AR(3) model may be underfitting, and incorporating additional lags, exogenous variables (like fuel type, hour-of-day effects), or moving average components (ARMA/ARIMA) might improve the model. But as it stands, the AR(3) model captures key temporal dependencies in the hourly output data.

*9.

use "/Users/vishakhasingla/Desktop/predoc/ercot task/edited data/merged_data", clear

gen double datetime = clock(sced_time_stamp, "MDYhm")
format datetime %tc
gen date = dofc(datetime)
format date %td

*(a)

*fuel type dummies

*we need to first convert it into a numeric variable, since it is a string variable right now
encode fuel_type, gen(fuel_type_cat)
label list fuel_type_cat 

* 1 Coal- reference category for the dummy regression
* 2 Natural Gas
* 3 Nuclear
* 4 Other
* 5 Solar
* 6 Wind

reg telemetered_net_output i.fuel_type_cat

*The regression output shows how electricity output (as measured by telemetered_net_output) varies across different fuel types, with the coal category omitted. The intercept, or constant term, represents the mean output for the coal fuel category. The coefficients for each fuel type indicate how their average output differs from this base category. For instance, units using Nuclear fuel produce, on average, 416.11 MW more than the base category, which is a large and statistically significant positive difference. Conversely, units powered by Natural Gas, Other fuels, Solar, and Wind all show significantly lower average outputs than the base: by 161.33 MW, 221.91 MW, 209.24 MW, and 183.02 MW respectively. All these differences are highly statistically significant (p < 0.001), suggesting that the type of fuel used is strongly associated with average electricity output. These results could reflect both the inherent generation capacities of each technology and their roles in the energy mix — for example, nuclear tends to operate at high and steady output levels, while renewables like solar and wind are more variable and often have lower capacity factors.

*(b)

gen byte day = dow(date)

label define daylbl 0 "Sun" 1 "Mon" 2 "Tues" 3 "Wed" 4 "Thurs" 5 "Fri" 6 "Sat"
label values day daylbl

*Sunday is the reference category

reg telemetered_net_output i.day

*The regression results examine how electricity output varies across the days of the week, using Sunday as the baseline category. The constant term of approximately 43.33 represents the average electricity output on Sundays. Compared to this, output is higher on all other days of the week. On Mondays, output increases by about 3.49 MW, and continues to rise through the week, peaking on Thursdays and Fridays, when the output is about 6.24 MW higher than on Sundays. Saturdays see a smaller increase of 3.12 MW, indicating a slight weekend dip relative to weekdays. All coefficients are statistically significant at the 1% level, as indicated by the very low p-values. However, despite this significance, the overall explanatory power of the model is minimal—reflected in the R-squared value of 0.0003—suggesting that while day-of-week has some predictive value, most of the variation in electricity output is driven by other factors. The pattern observed is consistent with typical work-week electricity demand cycles, with output rising on weekdays due to increased industrial and commercial activity and dipping slightly on weekends.

*(c)

* Generate a weekly variable
gen week = week(date)

* Step 3: Run dummy regression using week indicators
reg telemetered_net_output i.week

*The regression output shows the results of regressing electricity output  on dummy variables for weeks 5 to 8, with an omitted reference week 4. Each coefficient indicates the average difference in output for that week compared to the base week. The constant term (_cons) of 47.65 represents the average output in the base week. Week 5 had a significantly higher output, averaging 6.66 units more than the base week. Conversely, weeks 6, 7, and 8 show lower output, with decreases of 3.20, 2.16, and 3.95 units, respectively, compared to the base week. All coefficients are statistically significant at the 1% level, suggesting these differences are unlikely due to chance. However, the R-squared is only 0.0009, indicating that week-to-week variation explains less than 0.1% of the total variation in output. This suggests that while some weeks see higher or lower output, week itself is not a strong predictor, and there are likely many other factors (like fuel type, time of day, weather, etc.) driving generation levels.The weekly variation in electricity output reflected by the regression coefficients can be attributed to several underlying factors. Changes in weather conditions across weeks—such as variations in temperature, wind speed, or solar radiation—can significantly influence the output from renewable sources like solar and wind. Additionally, fluctuations in electricity demand, driven by industrial cycles, residential consumption patterns, or public holidays, can lead to changes in how much electricity is generated in a given week. 

************************************************************















