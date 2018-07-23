-- Prepare locales
Keyed_Localizations = {};
local default = "enUS";

function GetKeyedLocale()
	local locale = GetLocale();	
	if not Keyed_Localizations[locale] then
		return Keyed_Localizations[default];
	else 
		return Keyed_Localizations[locale];
	end
end
