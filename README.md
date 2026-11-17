# Feedlot Feed Efficiency: ADG, FCR and Feed Cost per kg Gain

A SQL case study on 150 feedlot steers: which animals turn feed into weight most cheaply, and what is that worth in rand?

**Case study page:** https://claude.ai/artifact/3dDUeSHkda2fu5QP5CPDCL

**Interactive dashboard (Tableau Public):** https://public.tableau.com/views/FeedlotFeedEfficiency/FeedlotFeedEfficiencyDashboard

## Key findings

- The most feed-efficient third of steers (lowest residual feed intake, RFI) ate **1.8 kg less dry matter per day** than the least efficient third (10.39 vs 12.22 kg) with the same daily gain (1.63 vs 1.65 kg/day) and the same carcass weight (about 400 kg).
- That is a **15% lower feed conversion ratio** (6.58 vs 7.70 kg feed per kg gain).
- At mid-November 2026 prices, efficient steers earned **R542 to R796 more income over feed cost per animal**, and the gap widened as feed prices rose.
- Treatment differences within trials were small. The bigger signal was variation between individual animals.

| Efficiency group | n | ADG (kg/d) | DMI (kg/d) | FCR | Feed cost per kg gain (R) | Income over feed (R) |
|---|---|---|---|---|---|---|
| Efficient (low RFI) | 51 | 1.63 | 10.39 | 6.58 | 35.68 | 1,046 |
| Average | 50 | 1.71 | 11.47 | 6.96 | 37.73 | 901 |
| Inefficient (high RFI) | 49 | 1.65 | 12.22 | 7.70 | 41.73 | 376 |

| Feed price scenario | Efficient (R) | Inefficient (R) | Advantage per animal (R) |
|---|---|---|---|
| Low | 1,768 | 1,226 | 542 |
| Base | 1,046 | 376 | 670 |
| High | 331 | -465 | 796 |

## Method

1. **Ask:** which feed-efficiency differences drive ADG, FCR and feed cost per kg of gain?
2. **Prepare:** loaded the data into PostgreSQL.
3. **Process:** derived days on feed as (final weight - initial weight) / ADG, then calculated FCR = DMI / ADG and feed cost per kg gain = FCR x ration price. Checked for missing and impossible values.
4. **Analyze:** compared trials and treatments, ranked steers by RFI within each trial and split them into thirds with `NTILE`, and calculated income over feed under three price scenarios.
5. **Share:** this repository, the case study page and a Tableau Public dashboard.

## Prices and assumptions (mid-November 2026)

- **Feed:** SAFEX yellow maize (YMAZ) Dec 2026, R3,971.60/ton, last traded 16 Nov 2026 (Grain SA, SAFEX Feeds page), converted at 88% dry matter = R4.51/kg DM. The base and high scenarios add 20% and 40% for the rest of the ration (R5.42 and R6.32). These mark-ups are assumptions.
- **Beef:** Class A cattle carcass R66.25/kg, week 46, released 13 Nov 2026 (RMIS National Livestock Prices Dashboard, data from ABSA), times the 64.3% average dressing of the steers = R42.60 per kg live gain.

## Limitations

- Income over feed is not profit. It excludes purchase price, labour, vet costs and interest.
- Three research trials with 150 steers. The pattern may not repeat exactly in another herd.
- No significance tests were run in SQL, and treatment groups had 14 to 18 animals.
- Prices are a snapshot from mid-November 2026.

## Files

| File | What it is |
|---|---|
| `feedlot_analysis_final.sql` | Full PostgreSQL script: table, price assumptions, views and all queries |
| `feedlot_steers.csv` | Dataset used (the "All data" sheet, columns renamed) |
| `results_efficiency_groups.csv` | Performance by efficiency group |
| `results_income_over_feed.csv` | Feed cost per kg gain and income over feed by group |
| `results_scenarios.csv` | Efficient vs inefficient income over feed by price scenario |

## How to reproduce

1. Create a PostgreSQL database.
2. Open `feedlot_analysis_final.sql`, and in Step 0 set the `\copy` path to your copy of `feedlot_steers.csv`.
3. Run the script. Step 0 drops and reloads `raw_steers`, so use a fresh database.

## Data source and licence

Beck, M. (2024). *Data for: Relationships between individual animal variation in dry matter intake and animal performance and feed efficiency.* Mendeley Data, V1. DOI: [10.17632/wcc46fhff8.1](https://doi.org/10.17632/wcc46fhff8.1). Related paper: DOI 10.15232/aas.2024-02583. The data were collated from three experiments (Beck et al., 2023; Proctor et al., 2024; Foote et al., 2024).

The dataset is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). **Changes made:** the "All data" sheet was exported to CSV with renamed columns, and days on feed, FCR, feed cost and efficiency groups were calculated in PostgreSQL. This analysis is independent and is not endorsed by the dataset's author.
