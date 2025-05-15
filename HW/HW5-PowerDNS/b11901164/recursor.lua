-- Debian default Lua configuration file for PowerDNS Recursor

-- Load DNSSEC root keys from dns-root-data package.
-- Note: If you provide your own Lua configuration file, consider
-- running rootkeys.lua too.
dofile("/usr/share/pdns-recursor/lua-config/rootkeys.lua")
addTA("cscat.tw", "7287 13 2 8e2836b6d38320464488b7edd80eb30d08f5b47bb8166804ddb6d3355c213bbe")
addTA("cscat.tw", "7287 13 4 30f5d74ab1582290b5c1bff0c423f9ea6a80e57d73e2df9c7351157c8f261ccce410fb31f28cd4d89f809172b7923772")

