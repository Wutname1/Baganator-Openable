local addonName, root = ... --[[@type string, table]]

-- The Core and bag systems are loaded by the .toc file before this
-- All we need to do here is ensure the addon is properly initialized

local addon = root.Core

-- The addon will automatically:
-- 1. Register with SpartanUI Logger in OnInitialize (if SpartanUI is present)
-- 2. Initialize the database in OnInitialize
-- 3. Detect and enable the appropriate bag system in OnEnable
-- 4. Register all options and handle configuration

-- No additional initialization required - the modular system handles everything