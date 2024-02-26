clear all
set more off
set matsize 11000
*ssc install mipolate

/**************************************************************************************************************************
	   Evolution of outcomes: We should plot the yearly values of the main statistics separately for three types of firms (MNC, Domestic Group, Non-Group). For details look at issue #21 on GitHub. 
   **************************************************************************************************************************/

/* DEFINING DIRECTORIES */


global 			project_do "C:\Users\lab-user\Desktop\McNabb\03 Waseem - Interest Limitation Event Study"									
global 			project_output "C:\Users\lab-user\Desktop\McNabb\03 Waseem - Interest Limitation Event Study\output_november"						
global 			project_input "C:\Users\lab-user\Desktop\McNabb\03 Waseem - Interest Limitation Event Study\input"		

global 			project_log "C:\Users\lab-user\Desktop\McNabb\03 Waseem - Interest Limitation Event Study\log_november"													
local			mytime = subinstr("`c(current_time)'",":","_",.)
local			mydate = subinstr("`c(current_date)'",":","_",.)
capture 		log close
log 			using 	"$project_log\9.Event Study.smcl", replace
di 				"`mytime'"
di 				"`mydate'"


* @Sebastian, please change the datafile name here
use			"$project_input\CIT PANEL 2014-2021.dta", clear
// keep 		if c_sectordescription!="K-Financial and insurance activities" // These firms are exempt from our treatment.
*Need to drop individuals?!* 
drop if 	c_taxpayertype =="INDI"
replace 	group=0 if group==.				// Kyle informed(7th Nov 2023) that missing group means they are not part of group
replace 	mnc=0 if mnc==. 				// Same for MNCs, they are not an mnc if mnc dummy is missing. 
duplicates  drop c_firm_id c_year, force 		// this does not matter as data is at firm-year level

rename 		pl_y_royalites pl_y_royalties
rename 		sch1_profit_loss_before_tax sch1_pl_before_tax
gen 		EBITDA = sch1_pl_before_tax + pl_x_interestexpense + sch1_add_depreciation	// This is the definition of EBITDA
****** Below we generate gross equity
g			gross_equity = bs_totalshareholderfunds + bs_totalloanfunds		// This is definition of gross equity
****** Below we generate debt and debt_to_equity variables
g			debt = bs_totalcurrentliability + bs_totalprovisions		// This is definition of the debt 
g			debt_to_equity = debt/gross_equity						
*************************
g  			tax_liability = 0.3*sch1_incm_bsns_actvty		// Kyle told that this should be true liability as sch1_incm_bsns_actvty is reported tax base 
******************** 07/10/2022 - Aggregate Variables
* Should we do rowtotal or not? How to deal with missing values? 
g			net_boovalue_fix_asets = bs_totalfixedassets - bs_accumulateddepreciation
g 			tot_cur_liab_pro = bs_totalcurrentliability + bs_totalprovisions
g 			total_assets = net_boovalue_fix_asets + bs_totalinvestments + bs_netcurrentasset + bs_deferredasset
g 			pft_lss_aft_adj_dep_capal = sch1_pl_before_tax + sch1_tot_amt_added - sch1_tot_deduct

******** Next, we generate the treatment variable for the IDL rule. The treatment variable in this case is the interest expense as a percentage of EBITDA
**** Basic Cleaning 
keep 		if pl_x_interestexpense >=0 		// Very few firm have negative interest expense and we decided to delete those. 
replace     EBITDA=0 if EBITDA==.	           // Mazhar suggested that just like interest expense, we should also convert missing EBITDA to be zero. Later we should check for cases when EBITDA is missing but profit before tax is not. 
replace 	pl_x_interestexpense=0 if pl_x_interestexpense==. // We assume not reporting interest expense means zero interest expense 
g			int_per = pl_x_interestexpense/EBITDA 				// This is our mean variable that defines treatment. 
g			type=0		//non-group firms
replace		type=1 if mnc==1	//mncs
replace		type=2 if mnc==0 & group==1	//domestic groups
preserve
foreach var of varlist pl_y_incometaxturnover total_assets tax_liability net_boovalue_fix_asets pl_y_totalsales pl_x_costofsales pl_grossprofit pl_x_interestexpense pl_profitbeforetax pl_profitaftertax sch1_pl_before_tax EBITDA int_per debt gross_equity debt_to_equity bs_totalfixedassets bs_totalinvestments {
        g `var'equal0=`var'==0 
		g `var'missing=`var'==.
        g `var'positive=(`var'>0 & `var'<.)
        g `var'negative=`var'<0
        * get mean median and 75th, 90th and 95th percentile by year 
        bys c_year type: egen `var'_mean=mean(`var')
        bys c_year type: egen `var'_median=median(`var')
        bys c_year type: egen `var'_p75=pctile(`var'), p(75)
        bys c_year type: egen `var'_p90=pctile(`var'), p(90)
        bys c_year type: egen `var'_p95=pctile(`var'), p(95)
        bys c_year type: egen `var'equal0_m=mean(`var'equal0)
        bys c_year type: egen `var'missing_m=mean(`var'missing)
        bys c_year type: egen `var'positive_m=mean(`var'positive)
        bys c_year type: egen `var'negative_m=mean(`var'negative)
        bys c_year type: g index=_n
        * save graph material in excel. 
        keep if index==1   // Keep only relevant observations for plot to be saved in excel 
        export excel `var'_mean `var'_median `var'_p75 `var'_p90 `var'_p95 `var'equal0_m `var'positive_m `var'negative_m c_year index mnc group type using "$project_output/`var'.xlsx", firstrow(variables) replace
        * Plot it for for MNCs, Groups and Domestic Groups seprately 
        foreach y of varlist `var'_mean `var'_median `var'_p75 `var'_p90 `var'_p95 `var'equal0_m `var'positive_m `var'negative_m {
        * MNC
        #d; 
        twoway connected `y' c_year if type==1 & index==1,sort lwidth(thick) lcolor(red) mcolor(red) msymbol(o)
		xtitle("Year") xscale(titlegap(*10)) 
		yscale(r(0))  yscale(titlegap(*10))  xline(2018, lpatter(dash) lcolor(green)) 
		graphregion(fcolor(white) style(none) color(white) margin(0 1.5 0 2)) bgcolor(white);
		graph 	export	"$project_output/`y'_MNC.png", replace;
		#d cr 

        * Domestic Group
        #d; 
        twoway connected `y' c_year if type==2 & index==1,sort lwidth(thick) lcolor(red) mcolor(red) msymbol(o)
		xtitle("Year") xscale(titlegap(*10)) 
		yscale(r(0))  yscale(titlegap(*10))  xline(2018, lpatter(dash) lcolor(green)) 
		graphregion(fcolor(white) style(none) color(white) margin(0 1.5 0 2)) bgcolor(white);
		graph 	export	"$project_output/`y'_DomesticGroups.png", replace;
		#d cr 
        * Non-Group
        #d; 
        twoway connected `y' c_year if type==0 & index==1,sort lwidth(thick) lcolor(red) mcolor(red) msymbol(o)
		xtitle("Year") xscale(titlegap(*10)) 
		yscale(r(0))  yscale(titlegap(*10))  xline(2018, lpatter(dash) lcolor(green)) 
		graphregion(fcolor(white) style(none) color(white) margin(0 1.5 0 2)) bgcolor(white);
		graph 	export	"$project_output/`y'_NonGroups.png", replace;
        #d cr 
        }
        restore 
        preserve 
     }
