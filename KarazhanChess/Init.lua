-------------------------------------------------------------------------------
-- Karazhan Chess
-- Author:  Mike D (MeloN <Convicted>)
--
-- Addon Namespace
-------------------------------------------------------------------------------

-- Every file receives the same private namespace table (ns) from the client.
-- The addon object and all classes live on it instead of in globals, and each
-- file pulls what it needs into locals. This file loads first so that KC
-- exists for everything after it.
local _, ns = ...

ns.KC = LibStub("AceAddon-3.0"):NewAddon("KarazhanChess", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0");
