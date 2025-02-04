CREATE DEFINER=`admin`@`localhost` PROCEDURE `pvlive`.`forwardfill`()
BEGIN
#Forward fill the pvgeneration table during hours of darkness today and ndays hence: 
#  generation_MW=0, capacity_MWp and installedcalacity_MWp same as yesterday.
#Julian Briggs
#4-feb-2025

declare ndays int default 7;
#
#Create and populate a temporary table of 48 timestamps at 30 minute intervals (on the hour and half hour) 
#from now (rounded up) and ndays days hence
DROP TEMPORARY TABLE IF EXISTS times;

DROP TEMPORARY TABLE IF EXISTS timestamps;

#Table times: column _time is generated from column i (just before a select)
create temporary table times (i int unsigned, _time time generated always as (time('00:00:00') + INTERVAL i * 30 MINUTE));

create temporary table timestamps (_date date, datetime_GMT timestamp );
#
#Populate table times: column _time is generated from column i (just before a select)
INSERT INTO times (i)
values (0),(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12),(13),(14),(15),(16),(17),(18),(19),(20),(21),(22),(23),(24),(25),(26),(27),(28),(29),(30),(31),(32),(33),(34),(35),(36),(37),(38),(39),(40),(41),(42),(43),(44),(45),(46),(47);
#
#Populate table timestamps with timestamps every 30 mins on the hour and half hour before sunrise and after sunset, today and ndays hence
insert into timestamps (datetime_GMT) select timestamp(ss.date, times._time)
from times
join pvstream.sunrise_sunset ss
where ss.date between CURRENT_DATE() and CURRENT_DATE() + interval ndays day
and times._time not between earliest_sunrise and latest_sunset;
#
#Forward fill table pvgeneration every 30 mins (on the hour and half hour) before sunrise and after sunset, today and ndays hence 
#Join table pvgeneration (single row yesterday at noon) to table gsp_20220314 (to get all gsp_ids, pvgenration=0, capacity_MWp, installedcapacity_MWp)
#Then join to table timestamps (to get rows for all gsps and all (48 half hourly) datetime_gmt)
insert into
	pvgeneration (gsp_id, datetime_GMT, generation_MW, capacity_MWp, installedcapacity_MWp
	 )
	 select g.gsp_id, timestamps.datetime_GMT, 0, capacity_MWp, installedcapacity_MWp
from gsp_20220314 g
join 
pvgeneration p on
(p.gsp_id = g.gsp_id
	and p.datetime_gmt = timestamp(CURRENT_DATE()- interval 12 hour))
join timestamps
order by
	g.gsp_id, timestamps.datetime_GMT
ON
DUPLICATE KEY UPDATE generation_MW = 0, capacity_MWp = p.capacity_MWp, installedcapacity_MWp = p.installedcapacity_MWp;

END