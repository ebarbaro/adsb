select 
h."hex_allocation",
p."hex",
r."reg",
p."flight",
p."alt_baro",
p."gs",
p."messages",
p."seen",
p."category",
p."squawk",
r."ownop",
r."mil",
p."SeenTimes",
p."FirstSeen",
p."trigger_timestamp",
p."nav_heading",
p."baro_rate",
p."lon",
p."lat",
p."emergency",
r."icaotype",
r."short_type",
r."year",
r."manufacturer",
r."model",
r."faa_pia",
r."faa_ladd"

from public."planes" as p 
inner join public."HexAllocation" as h on p."hex" = h."hex"
left join public."HexRegistration" as r on p."hex" = r."icao"

order by p."trigger_timestamp" desc, p."seen"