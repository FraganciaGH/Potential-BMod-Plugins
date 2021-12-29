#define PLUGIN_NAME "Balance Mod Jumper Knockback"
#define PLUGIN_DESCRIPTION "Gives normal knockback to jumper weapons"
#define PLUGIN_AUTHOR "Fragancia"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "Balancemod.tf"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
//#include <dhooks>
//#include <tf2condhooks>
#include <tf_ontakedamage> // Needs a modified TFOnTakeDamage with DamageForForce

#pragma newdecls required
#pragma semicolon 1

enum //Convar names
{
    CV_bDebugMode,
    CV_flDamagePenalty,
    CV_PluginVersion
}

/* Global Variables */

/* Global Handles */

//Handle g_hGameConf;

/* Dhooks */

/* Convar Handles */

ConVar g_cvCvarList[CV_PluginVersion+1];

/* Convar related global variables */

bool g_cv_bDebugMode;

float g_cv_flDamagePenalty;

public Plugin myinfo = 
{
    name = PLUGIN_NAME,
    author = PLUGIN_AUTHOR,
    description = PLUGIN_DESCRIPTION,
    version = PLUGIN_VERSION,
    url = PLUGIN_URL
};

public void OnPluginStart()
{

    /* DHooks Setup */

    //g_hGameConf = LoadGameConfigFile("");

    //Entity listener

    //DHookAddEntityListener(ListenType_Created, Hook);

    //delete g_hGameConf;

    /* Convars */

    g_cvCvarList[CV_PluginVersion] = CreateConVar("bm_jumper_knockback_version", PLUGIN_VERSION, "Plugin Version.", FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_CHEAT);

    g_cvCvarList[CV_bDebugMode] = CreateConVar("bm_jumper_kb_debug", "0", "Enable Debugging", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    
    g_cvCvarList[CV_flDamagePenalty] = CreateConVar("bm_jumper_kb_dmg_penalty", "0.05", "Damage penalty for Jumper Weapons", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    /* Convar global variables init */

    g_cv_bDebugMode = GetConVarBool(g_cvCvarList[CV_bDebugMode]);
    g_cv_flDamagePenalty = GetConVarFloat(g_cvCvarList[CV_flDamagePenalty]);

    /* Convar Change Hooks */

    g_cvCvarList[CV_bDebugMode].AddChangeHook(CvarChangeHook);
    g_cvCvarList[CV_flDamagePenalty].AddChangeHook(CvarChangeHook);

    /* Other */

    //RegAdminCmd("sm_", Command_, ADMFLAG_SLAY, "");
    

}

/* Publics */
public void OnMapStart()
{
}

public void OnClientPutInServer(int client)
{
}

public void OnEntityCreated(int entity, const char[] classname)
{
}
public Action TF2_OnTakeDamageModifyRulesEx(int victim, int &attacker, int &inflictor, float &damage, float &maxdamage, float &basedamage, float &damagebonus, int &damagetype, int &weapon, float damageForce[3],
		float damagePosition[3], int damagecustom, float &damageforforce, CritType &critType)
{
	if(IsJumperWeapon(weapon))
	{
		/*
			The plugin will handle the damage penalty so
			the plugin expects the jumper weapon to have
			their damage penalty attribute removed or
			things aren't gonna work!
		*/
		float flKnockback = damageforforce;
		basedamage *= g_cv_flDamagePenalty;
		damageforforce = flKnockback;
		
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public void CvarChangeHook(ConVar convar, const char[] sOldValue, const char[] sNewValue)
{
    if(convar == g_cvCvarList[CV_bDebugMode]) g_cv_bDebugMode = view_as<bool>(StringToInt(sNewValue));
    
    if(convar == g_cvCvarList[CV_flDamagePenalty]) g_cv_flDamagePenalty = StringToFloat(sNewValue);
}


/* Plugin Exclusive Functions */
bool IsJumperWeapon(int weapon)

{
    if(!IsValidWeapon(weapon)) 
	return false;
	
	switch(GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"))
	{
		case 237, 265:
		{
			return true;
		}
	}
	return false;
}

/* Stocks */

stock bool HasFlag(int client, int iFlags)
{
    if(iFlags & 1 << client)
    return true;

    return false;
}

stock int AddFlag(int client, int iFlags)
{
    if(!HasFlag(client, iFlags))
    {
        iFlags |= 1 << client;
        return iFlags;
    }
    return iFlags;
}

stock int RemoveFlag(int client, int iFlags)
{
    if(HasFlag(client, iFlags))
    {
        iFlags &= ~(1 << client);
        return iFlags;
    }
    return iFlags;
}
stock bool IsValidWeapon(int weapon)
{
    if(weapon > MaxClients && IsValidEntity(weapon)) 
    return true;
    
    return false;
}
stock bool IsValidClient(int client)
{
    return 0 < client <= MaxClients && IsClientInGame(client);
}