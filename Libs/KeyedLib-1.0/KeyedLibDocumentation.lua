local KeyedLibInfo =
{
	Name = "KeyedLibInfo",
	Type = "Library",
	Namespace = "KeyedLib",

	Functions =
	{
	
	},

	Tables =
	{
		{
			Name = "KeystoneEntry",
			Type = "Structure",
			Fields =
			{
				{ Name = "guid", Type = "string", Nilable = false },
				{ Name = "name", Type = "string", Nilable = false },
				{ Name = "level", Type = "number", Nilable = false },
				{ Name = "faction", Type = "number", Nilable = false },
				{ Name = "class", Type = "string", Nilable = false },
			},
		},
	},
};

-- I mean, I found this stuff in AddOns\Blizzard_APIDocumentation so i'm just gonna go along with it hehe
-- APIDocumentation:AddDocumentationTable(KeyedLibInfo);