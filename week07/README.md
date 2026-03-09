# In-Motion EV Charging Lane - Pilot Location Selection

## How to Run

### Declarative SQL (`declarative.sql`)

1. Open `declarative.sql` in Snowflake Snowsight or any SQL client that connects to Snowflake.
2. Make sure your role has read access to `DATA5035.SPRING26` (I used `TRAINING_ROLE`).
3. Set the warehouse to `SNOWFLAKE_LEARNING_WH` or whatever warehouse you have available.
4. Run the whole thing as one query. It's a single SELECT with a bunch of CTEs chained together — it doesn't create or change any tables.
5. You should get back 4 rows, one for each recommended pilot location.

Everything uses fully qualified table names (`DATA5035.SPRING26.<table>`), so you don't need to run any USE statements first.

### Imperative Python (`imperative.py`)

1. You'll need `snowflake-snowpark-python` installed.
2. Run it locally with `python week07/imperative.py`, or paste the code into a Snowflake Notebook.
3. If you go the notebook route, swap out `create_session()` for `get_active_session()` from `snowflake.snowpark.context` and drop the `if __name__` block at the bottom.
4. Every time you run it, it overwrites `week07/SEGMENTS.csv` with the latest results.

### Output File (`SEGMENTS.csv`)

`SEGMENTS.csv` gets refreshed on each Python run. It holds the same 4 pilot locations that the SQL query produces, just in CSV format so it's easy to share or open in Excel.

## Source Tables

| Table | What's in it |
|-------|-------------|
| ROAD_SEGMENTS | 10-mile highway segments with geometry, lane count, speed limits |
| TRAFFIC_COUNTS | Daily traffic volumes — total, EV, and truck breakdowns |
| POWER_INFRA | Locations of substations and transmission lines |
| INTERCHANGES | On/off ramp locations along each interstate |
| ENV_CONSTRAINTS | Polygons for wetlands and protected areas |
| WEATHER_RISK | A risk score per segment (higher = worse conditions) |
| INCIDENTS | Crash rate and incident rate per segment |

## How I Scored the Segments

Every eligible segment gets a composite score from four equally weighted categories (25% each). I went with equal weights because this is an early-stage pilot and I honestly didn't feel confident saying one factor matters way more than the others. If we had stakeholder input or historical data from similar projects, I'd probably adjust these.

### 1. Demand (25%)

Pretty straightforward — I ranked segments by their EV traffic volume (AADT_EV) using PERCENT_RANK. More EVs driving through means more potential users for the charging lane.

### 2. Feasibility (25%)

This one combines two things:
- **Power proximity (50% of feasibility)**: How close is the nearest substation or transmission line? You can't run a charging lane without a serious power source, so being near one matters a lot.
- **Low interchange density (30% of feasibility)**: Fewer interchanges nearby means fewer cars merging in and out. That matters because drivers need a calm, predictable stretch to slow down and use the charging lane.

I'll note that the sub-weights here only add up to 80% (0.50 + 0.30), not 100%. I noticed this after writing the query and decided to keep it since it still ranks segments in the right relative order — it just means the feasibility category can't quite reach its full 0.25 ceiling. If I were redoing this, I'd probably bump the remaining 20% into power proximity.

### 3. Safety (25%)

Three factors here:
- **Low crash rate (40% of safety)**: If a segment already has a lot of crashes, adding a slow lane there seems like a bad idea.
- **Low weather risk (35% of safety)**: Ice, fog, and storms would make a 30 mph charging lane even more dangerous. I weighted this almost as high as crash rate because Missouri winters can be rough.
- **Speed compatibility (25% of safety)**: I measured how close the posted speed limit is to 65 mph. My thinking was that slowing from 65 to 30 is a 35 mph gap, which feels more manageable than slowing from 70 to 30. This one I'm least sure about — it's kind of a judgment call.

### 4. Pilot Value (25%)

This is about picking a location that makes the pilot look good and generates useful data:
- **Strategic visibility (40% of pilot value)**: Higher-traffic segments mean more eyeballs on the project. I bucketed this into three tiers: over 60K AADT (full score), 40-60K (partial), under 40K (low).
- **Corridor importance (60% of pilot value)**: I-70 and I-55 are the main routes for each corridor, so I gave them a higher importance score than secondary interstates like I-64 or I-80. The idea is that a pilot on a primary route feels more significant.

## My Assumptions

### Segment Eligibility
- I threw out any segment that overlaps a wetland or protected area. Getting permits to build in those zones would take forever and could kill the project timeline.
- I required at least 4 lanes. You need room to dedicate one lane to charging without turning the highway into a bottleneck.

### Interchange Distance (5 km)
- I counted interchanges within 5 km of a segment. Merging traffic from an on-ramp tends to disrupt flow for about 1-2 miles in each direction, so 5 km (about 3 miles) felt like a reasonable buffer.

### Power Distance (30 km)
- I used a 30 km radius to count nearby power assets. Running a new transmission line much farther than that starts getting really expensive, so it seemed like a practical cutoff. In reality, this would need input from the local utility company.

### Geographic Spacing (50 miles)
- The second pick in each corridor has to be at least 50 miles from the first (or on a different interstate). I didn't want both picks clustered near St. Louis or near the same exit. Spreading them out means drivers across the whole corridor get some coverage.

### Speed Target (65 mph)
- I picked 65 mph as the "ideal" speed limit for the host segment. It's still a real highway, but the speed gap when you slow to 30 mph is a bit less scary than on a 70 mph road. Admittedly this is debatable.

### Corridor Assignment
- I-70 = St. Louis to Kansas City corridor.
- Everything else (I-55, I-64, I-57, I-80) = St. Louis to Chicago corridor.
- This is a simplification — some of those interstates don't actually go all the way to Chicago — but it works for grouping purposes.

### Equal Weights
- I gave all four categories the same 25% weight. I thought about weighting safety or demand higher, but without real stakeholder priorities or precedent data, equal weights felt like the most defensible starting point.

## Output Columns

| Column | What it shows |
|--------|-------------|
| SEGMENT_ID | Unique ID for the segment |
| INTERSTATE | Which interstate it's on |
| CORRIDOR | STL_KC or STL_CHI |
| MILE_RANGE | Mile marker start and end |
| LANES | Number of lanes |
| SPEED_LIMIT | Posted speed limit |
| AADT_TOTAL | Average daily traffic (all vehicles) |
| AADT_EV | Average daily EV traffic |
| AADT_TRUCK | Average daily truck traffic |
| PEAK_FACTOR | Peak hour multiplier |
| WEATHER_RISK_SCORE | Weather risk (0 = low, 1 = high) |
| CRASH_RATE | Crashes per million vehicle miles |
| INCIDENT_RATE | Incidents per million vehicle miles |
| NEAREST_POWER_KM | Distance to closest power infrastructure (km) |
| POWER_ASSETS_WITHIN_30KM | Number of substations/lines within 30 km |
| INTERCHANGES_NEARBY | Interchanges within 5 km |
| DEMAND_SCORE | EV demand score (0-0.25) |
| FEASIBILITY_SCORE | Infrastructure feasibility score (0-0.25) |
| SAFETY_SCORE | Safety score (0-0.25) |
| PILOT_VALUE_SCORE | Strategic value score (0-0.25) |
| COMPOSITE_SCORE | Total across all four categories (0-1.0) |
| RANK_IN_CORRIDOR | Rank within the corridor (1 = best) |
