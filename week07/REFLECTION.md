# Reflection on :In-Motion EV Charging Lane Pilot Location Selection

## Which Programming Paradigm Was Used Where?

In this project, I used both **declarative** and **imperative** programming paradigms.

The **declarative paradigm** was used in `declarative.sql`. In this file, the whole analysis is written as one SQL query using multiple **CTEs (Common Table Expressions)**. With SQL, I describe **what result I want**, such as joining tables, filtering rows, and ranking results. The database system then decides **how to execute the query** and optimize the process.

The **imperative paradigm** was used in `imperative.py`. In this version, I wrote the logic as a series of Python functions that run step by step inside the `main()` function. Each function performs a specific task, such as loading data, filtering rows, calculating scores, ranking the results, and exporting them to a CSV file. In this case, I control the **exact order of operations**.

## Why Was Each Paradigm Chosen?

I chose **SQL for the declarative version** because the main task of this project is working with data. The analysis requires joining multiple tables, filtering records, calculating values, and ranking results. SQL is designed specifically for these kinds of data operations, so it makes the code shorter and easier to read. Also, the database system can automatically optimize the query, which helps performance.

I used **Python for the imperative version** because it gives more flexibility and control. Python makes it easier to handle things like writing output to a CSV file, printing messages, or managing the database connection. Another advantage is that using functions allows me to test each step separately during development. For example, I could run one function to check intermediate results before running the whole pipeline.

## What Additional Data Would Improve Confidence?

There are several types of additional data that could make this analysis more accurate and reliable.

For example, **grid capacity data** would help determine whether nearby substations actually have enough available power to support EV charging infrastructure. Right now, the analysis only considers distance to power lines, not how much electricity they can provide.

**Land ownership information** would also be useful. The analysis currently excludes wetlands and protected areas, but it does not consider private land or other ownership restrictions that might prevent construction.

More detailed **traffic pattern data** would also improve the results. The current data uses annual averages, but EV charging demand likely changes depending on the time of day or season.

Another helpful dataset would be **road condition information**, such as pavement quality and road curvature. Some road segments may not be suitable for installing charging infrastructure due to safety concerns.

It would also help to know about **planned road construction or maintenance projects**. If a road is already scheduled for upgrades, installing charging infrastructure at the same time could reduce costs.

Finally, **EV adoption forecasts** by region would help predict future demand. Current EV traffic data shows the present situation, but planning infrastructure requires thinking about future growth.

## What Political or Operational Risks Exist?

### Political Risks

One possible risk is **community opposition**. Residents living near the selected highway segments may have concerns about construction, noise, or the visual impact of the infrastructure.

Another risk is **funding uncertainty**. Projects like this often rely on government funding, and changes in political priorities or leadership could reduce or remove financial support.

There could also be concerns about **regional fairness**. Since the pilot project focuses on specific highways, other regions might argue that they are not receiving equal investment.

If the charging corridor crosses state borders, there may also be **coordination challenges between states**, since each state has different regulations and planning processes.

Additionally, **utility regulations** could affect the project. Connecting high-power charging infrastructure to the electrical grid may require approval from regulators and cooperation from utility companies.

### Operational Risks

One operational risk is **technology maturity**: In-motion wireless charging technology is still relatively new, so there is a possibility that it may not perform as expected in real-world conditions.

Another concern is **maintenance**: Charging equipment embedded in the road may require specialized repairs, which could lead to lane closures and traffic disruption.

**Weather conditions**: are also a risk. Missouri experiences extreme weather such as ice storms, flooding, and high temperatures, which could damage the equipment over time.

There may also be **driver behavior and safety concerns**: If drivers need to slow down to use the charging lane, it could create speed differences between lanes and increase accident risk.

Finally, there is **demand uncertainty**: If EV adoption grows slower than expected, the charging lanes might not be used enough to justify the investment.
