#define PLUGIN_NAME "Balance Mod Gas Passer Molotov"
#define PLUGIN_DESCRIPTION "Turns Gas Passer into a molotov"
#define PLUGIN_AUTHOR "Fragancia"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "Balancemod.tf"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <dhooks>
#include <tf_ontakedamage>
//#include <tf2condhooks>

#pragma newdecls required
#pragma semicolon 1

enum //Convar names
{
    CV_bDebugMode,
    CV_flFireDuration,
    CV_flGasDuration,
    CV_PluginVersion
}

/* Global Variables */

//Used to track how many gas clouds a player is currently touching
int g_iIsTouchingGas[MAXPLAYERS+1]; 

/* Global Handles */
StringMap g_smPlayersTouchingGas;
//Handle g_hGameConf;

/* Dhooks */

/* Convar Handles */

ConVar g_cvCvarList[CV_PluginVersion+1];

/* Convar related global variables */

bool g_cv_bDebugMode;

float g_cv_flFireDuration;
float g_cv_flGasDuration;

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

    g_cvCvarList[CV_PluginVersion] = CreateConVar("bm_gas_passer_molotov_version", PLUGIN_VERSION, "Plugin Version.", FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_CHEAT);

    g_cvCvarList[CV_bDebugMode] = CreateConVar("bm_gpm_debug", "1", "Enable Debugging", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    
    g_cvCvarList[CV_flFireDuration] = CreateConVar("bm_gpm_fire_duration", "10.0", "How long the fire from touching gas lasts", FCVAR_NOTIFY, true, 0.0, true, 60.0);
    
    g_cvCvarList[CV_flGasDuration] = CreateConVar("bm_gpm_gas_duration", "10.0", "How long the applied gas lasts", FCVAR_NOTIFY, true, 0.0, true, 60.0);

    /* Convar global variables init */

    g_cv_bDebugMode = GetConVarBool(g_cvCvarList[CV_bDebugMode]);
    
    g_cv_flFireDuration = GetConVarFloat(g_cvCvarList[CV_flFireDuration]);
    g_cv_flGasDuration = GetConVarFloat(g_cvCvarList[CV_flGasDuration]);

    /* Convar Change Hooks */

    g_cvCvarList[CV_bDebugMode].AddChangeHook(CvarChangeHook);
    
    g_cvCvarList[CV_flFireDuration].AddChangeHook(CvarChangeHook);
    g_cvCvarList[CV_flGasDuration].AddChangeHook(CvarChangeHook);

    /* Other */
	g_smPlayersTouchingGas = new StringMap();
    //RegAdminCmd("sm_", Command_, ADMFLAG_SLAY, "");
    

}

/* Publics */
public void OnMapStart()
{
	//Cleanup
	g_smPlayersTouchingGas.Clear();
	for(int client = 1; client <= MaxClients; client++)
	{
		g_iIsTouchingGas[client] = 0;
	}
}
public Action TF2_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage,
		int &damagetype, int &weapon, float damageForce[3], float damagePosition[3],
		int damagecustom, CritType &critType)
{
	if(damagecustom == TF_CUSTOM_BURNING 
	&& g_iIsTouchingGas[victim] > 0)
	{
		/* Confirm: Does this only make afterburn crit or does it apply to any fire? */
		critType = CritType_Crit;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}
public void OnClientDisconnect(int client)
{
	/*
	int playersTouchingGas;
	if(!g_smPlayersTouchingGas.GetValue(sBuffer, playersTouchingGas))
	return;
	
	if(HasFlag(client, playersTouchingGas))
	{
		playersTouchingGas = RemoveFlag(client, playersTouchingGas);
		if(g_iIsTouchingGas[client] <= 0)
		{
			g_iIsTouchingGas = 0;
		}
		else
		{
			g_iIsTouchingGas[client]--;
		}
		g_smPlayersTouchingGas.SetValue(sBuffer, playersTouching, false);
	}
	*/
}
public void OnEntityCreated(int entity, const char[] classname)
{
    if(strcmp(classname, "tf_gas_manager") == 0)
    {
        SDKHook(entity, SDKHook_StartTouch, OnGasStartTouch);
        
        /*
        EndTouch doesn't fire when the entity is destroyed
        so we have to store what players are touching gas
        */
        SDKHook(entity, SDKHook_EndTouch, OnGasEndTouch);
        
        //Touch is too expensive, don't use
        //SDKHook(entity, SDKHook_Touch, OnGasTouch);
        //PrintToConsoleAll("Hooked Gas Manager: %i", entity);
        
        SetPlayersTouchingGas(entity);
    }
}
public void OnEntityDestroyed(int entity)
{
	/* 
	Check if it's a Gas Passer cloud entity 
	and do appropriate actions when removed.
	*/
	// Confirm: Is it too late to get the classname here?
	char sBuffer[32];
	GetEntityClassname(entity, sBuffer, sizeof(sBuffer));
	
	if(strcmp(sBuffer, "tf_gas_manager") == 0)
	{
		int playersTouchingGas = GetPlayersTouchingGas(entity);
		for(int client = 1; client <= MaxClients; client++)
		{
			if(HasFlag(client, playersTouchingGas))
			{
				if(g_iIsTouchingGas[client] <= 0)
				{
					g_iIsTouchingGas[client] = 0;
				}
				else
				{
					g_iIsTouchingGas[client]--;
				}
			}
		}
		g_smPlayersTouchingGas.Remove(sBuffer);
	}
}
public Action OnGasStartTouch(int entity, int other)
{
    //PrintToChatAll("Gas Manager: %i", entity);
    //PrintToChatAll("GM started touching: %i", other);
    if(IsValidClient(other))
    {
    	// Confirm: Is OwnerEntity the player or the Gas Passer weapon?
    	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
    	/*
    	We use a stringmap and make a keyvalue pair
		for each gas cloud to track players touching them
    	*/
    	if(AddPlayerTouchingGas(other, entity))
    	{
    		//Apply gas condition if they don't have
    		if(!TF2_IsPlayerInCondition(other, TFCond_Gas))
    		TF2_AddCondition(other, TFCond_Gas, g_cv_flGasDuration, entity);
    		// Ignite players entering the cloud not already on fire
    		if(!TF2_IsPlayerInCondition(other, TFCond_OnFire))
    		TF2_IgnitePlayer(other, owner, g_cv_flFireDuration);
    	}
        //PrintToChatAll("Hooked %N EndTouch", other);
        //SDKHook(other, SDKHook_EndTouch, OnPlayerGasEndTouch);
    }
    return Plugin_Continue;
}
public Action OnGasEndTouch(int entity, int other)
{
    //PrintToChatAll("Gas Manager: %i", entity);
    //PrintToChatAll("GM ended touching: %i", other);
	if(IsValidClient(other))
    {
    	RemovePlayerTouchingGas(other, entity);
    }
    return Plugin_Continue;
}
/*
public Action OnGasTouch(int entity, int other)
{
    //PrintToChatAll("Gas Manager: %i", entity);
    //PrintToChatAll("GM currently touching: %i", other);

    return Plugin_Continue;
}
*/

public void CvarChangeHook(ConVar convar, const char[] sOldValue, const char[] sNewValue)
{
    if(convar == g_cvCvarList[CV_bDebugMode]) g_cv_bDebugMode = view_as<bool>(StringToInt(sNewValue));
    
    if(convar == g_cvCvarList[CV_flFireDuration]) g_cv_flFireDuration = StringToFloat(sNewValue);
    
    if(convar == g_cvCvarList[CV_flGasDuration]) g_cv_flGasDuration = StringToFloat(sNewValue);
}

/* Plugin Exclusive Functions */
bool AddPlayerTouchingGas(int client, int entity)
{
	char sBuffer[16];
	int playersTouchingGas;

	IntToString(entity, sBuffer, sizeof(sBuffer));
	
	if(!g_smPlayersTouchingGas.GetValue(sBuffer, playersTouchingGas))
	return false;
	
	if(!HasFlag(client, playersTouchingGas))
	{
		playersTouchingGas = AddFlag(client, playersTouchingGas);
		g_iIsTouchingGas[client]++;
		return g_smPlayersTouchingGas.SetValue(sBuffer, playersTouchingGas, false);
	}
	
	return false;
}
bool RemovePlayerTouchingGas(int client, int entity)
{
	char sBuffer[16];
	int playersTouchingGas;

	IntToString(entity, sBuffer, sizeof(sBuffer));
	
	if(!g_smPlayersTouchingGas.GetValue(sBuffer, playersTouchingGas))
	return false;
	
	if(HasFlag(client, playersTouchingGas))
	{
		playersTouchingGas = RemoveFlag(client, playersTouchingGas);
		if(g_iIsTouchingGas[client] <= 0)
		{
			g_iIsTouchingGas[client] = 0;
		}
		else
		{
			g_iIsTouchingGas[client]--;
		}
		return g_smPlayersTouchingGas.SetValue(sBuffer, playersTouchingGas, false);
	}
	
	return false;
}
int GetPlayersTouchingGas(int entity)
{
	char sBuffer[16];
	int playersTouchingGas;

	IntToString(entity, sBuffer, sizeof(sBuffer));
	
	if(!g_smPlayersTouchingGas.GetValue(sBuffer, playersTouchingGas))
	return -1;
	
	return playersTouchingGas;
}
bool SetPlayersTouchingGas(int entity, int playersTouchingGas = 0)
{
	char sBuffer[16];
	IntToString(entity, sBuffer, sizeof(sBuffer));
	
	return g_smPlayersTouchingGas.SetValue(sBuffer, playersTouchingGas);
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

stock bool IsValidClient(int client)
{
    return 0 < client <= MaxClients && IsClientInGame(client);
}