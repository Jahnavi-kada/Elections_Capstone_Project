create database elections;
use elections;
select * from ge_2024_results;
select count(*) from ge_2024_results;

# Find the candidate with the highest percentage of votes in each state.

SELECT state, candidate, percentage_of_votes
FROM ge_2024_results AS g1
WHERE percentage_of_votes = ( SELECT MAX(percentage_of_votes) FROM ge_2024_results AS g2 WHERE g1.state = g2.state)
ORDER BY state
LIMIT 10;

# List all candidates who received more than the average total votes.

SELECT AVG(total_votes) FROM ge_2024_results;

SELECT candidate, SUM(Total_Votes) AS tot
FROM ge_2024_results
group by candidate 
having tot > (SELECT AVG(total_votes) FROM ge_2024_results);

# Find the average EVM votes per state and then list all candidates who received higher than the average EVM votes in their state.

SELECT state, candidate, evm_votes, avg_evm_votes
FROM (SELECT state, candidate, evm_votes, AVG(evm_votes) OVER (PARTITION BY state) AS avg_evm_votes FROM ge_2024_results) AS state_avg
WHERE evm_votes > avg_evm_votes
ORDER BY state, evm_votes DESC;

# Find the candidates within the same party who have the maximum and minimum total votes in each state.

SELECT max_results.state, max_results.party,
max_results.candidate_with_max_votes, max_results.max_votes, 
min_results.candidate_with_min_votes, min_results.min_votes
FROM 
(SELECT state, party, candidate AS candidate_with_max_votes, total_votes AS max_votes
FROM
(SELECT state, party, candidate, SUM(Total_Votes) AS total_votes,
RANK() OVER (PARTITION BY state, party ORDER BY SUM(Total_Votes) DESC) AS rank_max
FROM ge_2024_results
GROUP BY state, party, candidate) AS max_candidates
WHERE rank_max = 1) AS max_results
JOIN 
(SELECT state, party, candidate AS candidate_with_min_votes, total_votes AS min_votes
FROM 
(SELECT state, party, candidate, SUM(Total_Votes) AS total_votes,
RANK() OVER (PARTITION BY state, party ORDER BY SUM(Total_Votes)) AS rank_min
FROM ge_2024_results
GROUP BY state, party, candidate) AS min_candidates
WHERE rank_min = 1) AS min_results
ON max_results.state = min_results.state AND max_results.party = min_results.party;

# List all constituencies where the difference in total votes between the winner and the runner-up is less than 5%.

WITH ranked_results AS 
(
SELECT constituency, state, candidate, SUM(total_votes) AS total_votes,
LEAD(candidate) OVER (PARTITION BY state, constituency ORDER BY SUM(total_votes) DESC) AS runner_up,
LEAD(SUM(total_votes)) OVER (PARTITION BY state, constituency ORDER BY SUM(total_votes) DESC) AS runner_up_votes
FROM ge_2024_results
GROUP BY constituency, state, candidate
)
SELECT constituency, state, candidate AS winner, total_votes AS winner_votes, runner_up, runner_up_votes,
ABS(total_votes - runner_up_votes) / total_votes * 100 AS vote_difference_percentage
FROM ranked_results
WHERE runner_up_votes IS NOT NULL
AND ABS(total_votes - runner_up_votes) / total_votes * 100 < 5;

#2)

WITH ranked_results AS 
(SELECT state, constituency, candidate, SUM(total_votes) AS total_votes,
RANK() OVER (PARTITION BY state, constituency ORDER BY SUM(total_votes) DESC) AS rank_position
FROM ge_2024_results
GROUP BY state, constituency, candidate)
SELECT r1.constituency, r1.state, 
r1.candidate AS winner, r1.total_votes AS winner_votes,
r2.candidate AS runner_up, r2.total_votes AS runner_up_votes,
ABS(r1.total_votes - r2.total_votes) / (r1.total_votes + r2.total_votes) * 100 AS vote_difference_percentage
FROM ranked_results r1
JOIN
ranked_results r2
ON r1.state = r2.state 
AND r1.constituency = r2.constituency
AND r2.rank_position = r1.rank_position + 1
WHERE r1.rank_position = 1
AND ABS(r1.total_votes - r2.total_votes) / (r1.total_votes + r2.total_votes) * 100 < 5;

# For each constituency, get the difference of the number of the votes between the winner and runner-up.

#1)

WITH ranked_results AS 
(
SELECT constituency, state, candidate, SUM(total_votes) AS total_votes,
LEAD(candidate) OVER (PARTITION BY state, constituency ORDER BY SUM(total_votes) DESC) AS runner_up,
LEAD(SUM(total_votes)) OVER (PARTITION BY state, constituency ORDER BY SUM(total_votes) DESC) AS runner_up_votes
FROM ge_2024_results
GROUP BY constituency, state, candidate
)
SELECT constituency, state, 
candidate AS winner,total_votes AS winner_votes,
runner_up, runner_up_votes,
ABS(total_votes - runner_up_votes) AS vote_difference
FROM ranked_results
WHERE runner_up IS NOT NULL;

#2)

WITH ranked_results AS 
(
SELECT constituency, state, candidate, SUM(total_votes) AS total_votes,
RANK() OVER (PARTITION BY state, constituency ORDER BY SUM(total_votes) DESC) AS rank_position
FROM ge_2024_results
GROUP BY constituency, state, candidate
)
SELECT r1.constituency, r1.state, r1.candidate AS winner, r1.total_votes AS winner_votes, 
r2.candidate AS runner_up, r2.total_votes AS runner_up_votes,
ABS(r1.total_votes - r2.total_votes) AS vote_difference
FROM ranked_results r1
JOIN ranked_results r2
ON r1.state = r2.state AND r1.constituency = r2.constituency AND r2.rank_position = r1.rank_position + 1
WHERE r1.rank_position = 1;

# Calculate the share of total votes each candidate received out of the total votes in their state.

SELECT state, candidate, SUM(total_votes) AS candidate_votes, (SUM(total_votes) / state_total_votes) * 100 AS vote_share_percentage
FROM 
( SELECT state, candidate, total_votes, SUM(total_votes) OVER (PARTITION BY state) AS state_total_votes
FROM ge_2024_results
) AS vote_data
GROUP BY state, candidate, state_total_votes
ORDER BY state, vote_share_percentage DESC;


# List all constituencies where the total percentage of votes from the top 3 candidates (by total votes) 
# in each constituency exceeds 150%, and the total votes in that constituency are more than 1 million.

SELECT r.state,
       r.constituency,
       r.candidate,
       r.total_votes,
       r.percentage_of_Votes,
       (SELECT SUM(percentage_of_Votes) 
        FROM (SELECT candidate, percentage_of_Votes 
              FROM ge_2024_results 
              WHERE state = r.state 
              AND constituency = r.constituency 
              ORDER BY total_votes DESC 
              LIMIT 3) AS top_3_candidates) AS top_3_percentage_sum
FROM ge_2024_results r
WHERE (SELECT SUM(total_votes) 
       FROM ge_2024_results 
       WHERE state = r.state 
         AND constituency = r.constituency) > 1000000
  AND (SELECT SUM(percentage_of_Votes) 
       FROM (SELECT candidate, percentage_of_Votes 
             FROM ge_2024_results 
             WHERE state = r.state 
             AND constituency = r.constituency 
             ORDER BY total_votes DESC 
             LIMIT 3) AS top_3_candidates) > 150
ORDER BY r.state, r.constituency;

# Identify the top 3 candidates by total votes in each constituency, 
# but only in constituencies where the difference in percentage of votes between the winner and runner-up is less than 3%.

WITH ranked_candidates AS (
    SELECT state,
           constituency,
           candidate,
           total_votes,
           percentage_of_Votes,
           RANK() OVER (PARTITION BY state, constituency ORDER BY total_votes DESC) AS rank_position
    FROM ge_2024_results
),
vote_difference AS (
    SELECT state,
           constituency,
           MAX(CASE WHEN rank_position = 1 THEN percentage_of_Votes ELSE 0 END) AS winner_percentage,
           MAX(CASE WHEN rank_position = 2 THEN percentage_of_Votes ELSE 0 END) AS runner_up_percentage
    FROM ranked_candidates
    GROUP BY state, constituency
)
SELECT r.state,
       r.constituency,
       r.candidate,
       r.total_votes,
       r.percentage_of_Votes
FROM ranked_candidates r
JOIN vote_difference v
  ON r.state = v.state
  AND r.constituency = v.constituency
WHERE r.rank_position <= 3
  AND ABS(v.winner_percentage - v.runner_up_percentage) < 3
ORDER BY r.state, r.constituency, r.rank_position;

# For each state, calculate the total percentage of votes for Party X in each constituency and 
# compare it with the average percentage for Party X across the entire state. 
# List only constituencies where Party X's percentage exceeds the state average

WITH state_avg_percentage AS (
    SELECT state,
           party,
           AVG(percentage_of_Votes) AS avg_percentage
    FROM ge_2024_results
    WHERE party = 'Bharatiya Janata Party'
    GROUP BY state, party
),
constituency_percentage AS (
    SELECT state,
           constituency,
           party,
           SUM(percentage_of_Votes) AS total_percentage
    FROM ge_2024_results
    WHERE party = 'Bharatiya Janata Party'
    GROUP BY state, constituency, party
)
SELECT c.state,
       c.constituency,
       c.total_percentage,
       s.avg_percentage
FROM constituency_percentage c
JOIN state_avg_percentage s
  ON c.state = s.state
WHERE c.total_percentage > s.avg_percentage
ORDER BY c.state, c.constituency;

# For each party, find the candidate with the highest percentage of votes in each constituency and 
# compare their percentage of votes with the average percentage of votes for that party across the entire state.

WITH party_avg_percentage AS (
    SELECT state,
           party,
           AVG(percentage_of_Votes) AS avg_percentage
    FROM ge_2024_results
    GROUP BY state, party
),
max_votes_per_constituency AS (
    SELECT state,
           constituency,
           party,
           candidate,
           percentage_of_Votes,
           RANK() OVER (PARTITION BY state, constituency, party ORDER BY percentage_of_Votes DESC) AS rank_position
    FROM ge_2024_results
)
SELECT m.state,
       m.constituency,
       m.party,
       m.candidate,
       m.percentage_of_Votes AS candidate_percentage,
       p.avg_percentage AS party_avg_percentage
FROM max_votes_per_constituency m
JOIN party_avg_percentage p
  ON m.state = p.state AND m.party = p.party
WHERE m.rank_position = 1
ORDER BY m.state, m.constituency;

# For each party, calculate the total number of votes (EVM + Postal) across all constituencies in each state and 
# rank the parties within each state based on the total votes they received. List the top 2 parties for each state.

WITH total_votes_per_party AS (
    SELECT state,
           party,
           SUM(EVM_Votes + Postal_Votes) AS total_votes
    FROM ge_2024_results
    GROUP BY state, party
),
ranked_parties AS (
    SELECT state,
           party,
           total_votes,
           RANK() OVER (PARTITION BY state ORDER BY total_votes DESC) AS rank_position
    FROM total_votes_per_party
)
SELECT r.state,
       r.party,
       r.total_votes
FROM ranked_parties r
WHERE r.rank_position <= 2
ORDER BY r.state, r.rank_position;

# List the constituencies where Party A has the highest number of votes, but Party B has a higher percentage of votes.

/* WITH total_votes_per_party AS (
    SELECT state,
           constituency,
           party,
           SUM(EVM_Votes + Postal_Votes) AS total_votes
    FROM ge_2024_results
    GROUP BY state, constituency, party
),
party_percentage AS (
    SELECT state,
           constituency,
           party,
           SUM(percentage_of_Votes) AS total_percentage
    FROM ge_2024_results
    GROUP BY state, constituency, party
)
SELECT t1.state,
       t1.constituency,
       t1.party AS party_a,
       t1.total_votes AS party_a_votes,
       t2.party AS party_b,
       t2.total_percentage AS party_b_percentage
FROM total_votes_per_party t1
JOIN party_percentage t2
  ON t1.state = t2.state
  AND t1.constituency = t2.constituency
WHERE t1.party = 'Bharatiya Janata Party'
  AND t2.party = 'Indian National Congress'
  AND t1.total_votes > t2.total_votes
  AND t2.total_percentage > t1.total_percentage
ORDER BY t1.state, t1.constituency; */

# Find the top 5 candidates with the highest percentage of votes in each constituency.

WITH candidate_percentage AS (
    SELECT state, constituency, candidate, party, total_votes,
           (total_votes / (SELECT SUM(total_votes) 
                           FROM ge_2024_results 
                           WHERE state = r.state AND constituency = r.constituency) * 100) AS percentage_of_votes
    FROM ge_2024_results r
)
SELECT state, constituency, candidate, party, percentage_of_votes
FROM (
    SELECT state, constituency, candidate, party, percentage_of_votes,
           RANK() OVER (PARTITION BY state, constituency ORDER BY percentage_of_votes DESC) AS rank_position
    FROM candidate_percentage
) AS ranked_candidates
WHERE rank_position <= 5
ORDER BY state, constituency, rank_position;

#  Calculate the total number of votes received by each party in each state and compare it to the total number of votes in the state.

WITH party_total_votes AS (
    SELECT state, party, SUM(total_votes) AS total_votes
    FROM ge_2024_results
    GROUP BY state, party
),
state_total_votes AS (
    SELECT state, SUM(total_votes) AS total_votes
    FROM ge_2024_results
    GROUP BY state
)
SELECT p.state, p.party, p.total_votes AS party_total_votes,
       s.total_votes AS state_total_votes,
       (p.total_votes / s.total_votes) * 100 AS percentage_of_state_votes
FROM party_total_votes p
JOIN state_total_votes s
  ON p.state = s.state
ORDER BY p.state, p.party;

# Get the average vote percentage for each party in each state, 
# and list the constituencies where the candidate received above the average vote percentage for their party.

WITH party_avg_percentage AS (
    SELECT state, party, AVG(percentage_of_votes) AS avg_percentage
    FROM ge_2024_results
    GROUP BY state, party
)
SELECT r.state, r.constituency, r.candidate, r.party, r.percentage_of_votes
FROM ge_2024_results r
JOIN party_avg_percentage p
  ON r.state = p.state AND r.party = p.party
WHERE r.percentage_of_votes > p.avg_percentage
ORDER BY r.state, r.constituency;
