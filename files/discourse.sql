-- Pigsty Discourse baseline: keep the dedicated owner outside shared demo roles.
-- Run after pg-db.sql; it re-applies shared default grants on subsequent runs.
-- This baseline is for the default discourse database and discourse owner.
\set ON_ERROR_STOP on

REVOKE CREATE ON DATABASE discourse FROM dbrole_admin;
REVOKE ALL ON SCHEMA public FROM PUBLIC, dbrole_readonly, dbrole_offline, dbrole_readwrite, dbrole_admin;
GRANT USAGE, CREATE ON SCHEMA public TO discourse;

ALTER DEFAULT PRIVILEGES FOR ROLE discourse REVOKE ALL ON SCHEMAS FROM dbrole_readonly, dbrole_offline, dbrole_readwrite, dbrole_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE discourse REVOKE ALL ON TABLES FROM dbrole_readonly, dbrole_offline, dbrole_readwrite, dbrole_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE discourse REVOKE ALL ON SEQUENCES FROM dbrole_readonly, dbrole_offline, dbrole_readwrite, dbrole_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE discourse REVOKE ALL ON FUNCTIONS FROM PUBLIC, dbrole_readonly, dbrole_offline, dbrole_readwrite, dbrole_admin;

-- Include existing objects when this baseline is applied to an existing forum.
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC, dbrole_readonly, dbrole_offline, dbrole_readwrite, dbrole_admin;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC, dbrole_readonly, dbrole_offline, dbrole_readwrite, dbrole_admin;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, dbrole_readonly, dbrole_offline, dbrole_readwrite, dbrole_admin;
-- Extensions are installed by the DBA; their functions still need app access.
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO discourse;
