/*
Author: Nyaaaa (STEAM_0:1:37408546)
Description: Saveloc system to help with practicing surf/bhop maps.
Based on tm-saveloc by horsefeathers.
*/

#include <sourcemod>
#include <sdktools>

#define DEFAULT_MAX_LOCS "250"
#define DEFAULT_CHAT_TAG "[SM] "

// float vectors saving the positions, angles, and velocities of each client
// add one because client indexes start on 1 (0 is server)

ConVar	  g_Convar_MaxLocs;
ConVar	  g_Convar_ChatTag;

ArrayList g_Array_posData;
ArrayList g_Array_angData;
ArrayList g_Array_velData;

int		  g_Int_currentLoc[MAXPLAYERS + 1] = { 0, ... };

char	  g_chatTag[128];
int		  locCount = 0;

// plugin info
public Plugin myinfo =
{
	name		= "surf-Saveloc",
	author		= "Nyaaaa~ [U:1:74817093]",
	description = "Surf/Bhop saveloc plugin.",
	version		= "1.0",
	url			= ""
};

public OnPluginStart()
{
	RegConsoleCmd("sm_saveloc", Command_SaveLoc);

	RegConsoleCmd("sm_tele", Command_Teleport);
	RegConsoleCmd("sm_teleport", Command_Teleport);

	RegConsoleCmd("sm_prev", Command_Previous);
	RegConsoleCmd("sm_previous", Command_Previous);
	RegConsoleCmd("sm_teleprev", Command_Previous);

	RegConsoleCmd("sm_next", Command_Next);
	RegConsoleCmd("sm_telenext", Command_Next);

	g_Convar_MaxLocs = CreateConVar("saveloc_maxlocations", DEFAULT_MAX_LOCS, "Maximum number of save locations. Set to -1 to disable limit and 0 to disable saveloc entirely.", FCVAR_NONE, true, -1.0, false);
	g_Convar_ChatTag = CreateConVar("saveloc_chattag", DEFAULT_CHAT_TAG, "Tag to use before all output in chat. If using a tag, leave a blank space at the end.", FCVAR_NONE);

	// create config files in cfg/sourcemod/
	AutoExecConfig(true, "saveloc_config");

	// Each array will store arrays of size 3
	g_Array_posData = new ArrayList(3);
	g_Array_angData = new ArrayList(3);
	g_Array_velData = new ArrayList(3);

	g_Convar_ChatTag.GetString(g_chatTag, 128);
}

// command callbacks
public Action Command_SaveLoc(client, args)
{
	int maxLocs = g_Convar_MaxLocs.IntValue;
	if (maxLocs == 0.0)
	{
		PrintToChat(client, "%sSaveloc is currently disabled!", g_chatTag);
		return Plugin_Handled;
	}
	// check if player is alive
	if (client > 0 && IsPlayerAlive(client))
	{
		if (maxLocs != -1 && locCount >= maxLocs)
		{
			PrintToChat(client, "%sMaximum number of savelocs reached (%i)!", g_chatTag, maxLocs);
			return Plugin_Handled;
		}

		float origin[3];
		GetClientAbsOrigin(client, origin);	   // save position
		float angles[3];
		GetClientEyeAngles(client, angles);	   // save angles
		float velocity[3];
		GetClientVelocity(client, velocity);	// save velocity - internal

		g_Array_posData.PushArray(origin);
		g_Array_angData.PushArray(angles);
		g_Array_velData.PushArray(velocity);

		locCount++;

		g_Int_currentLoc[client] = locCount;
		// debug
		// PrintToConsole(client, "save vel: %f, %f, %f",
		// velData[client][0],velData[client][1],velData[client][2]);

		PrintToChat(client, "%sLocation #%d Saved.", g_chatTag, locCount);	  // notify client
	}
	else	// print out error and exit
	{
		PrintToChat(client, "%sMust be alive to Saveloc!", g_chatTag);
	}
	return Plugin_Handled;
}

public Action Command_Teleport(client, args)
{
	int locationNum = 0;

	if (args == 0)
	{
		locationNum = g_Int_currentLoc[client];
	}
	else
	{
		char arg[5];
		GetCmdArg(1, arg, sizeof(arg));
		locationNum = StringToInt(arg);
	}

	TelePlayer(client, locationNum);

	return Plugin_Handled;
}

public Action Command_Previous(client, args) {
	int loc = g_Int_currentLoc[client] - 1;

	if (loc <= 0) {
		loc = locCount;
	}

	TelePlayer(client, loc);
	return Plugin_Handled;
}

public Action Command_Next(client, args) {
	int loc = g_Int_currentLoc[client] + 1;

	if (loc > locCount) {
		loc = 1;
	}

	TelePlayer(client, loc);
	return Plugin_Handled;
}

public TelePlayer(client, int locationNum)
{
	if (client < 0) {
		return;
	}
	
	if (!IsPlayerAlive(client))
	{
		PrintToChat(client, "%sMust be alive to Saveloc!", g_chatTag);
		return;
	}

	if (locationNum <= 0 || locationNum > locCount)
	{
		return;
	}

	float pos[3];
	float ang[3];
	float vel[3];

	// Get From array at number provided-1 as array starts at 0
	GetArrayArray(g_Array_posData, locationNum - 1, pos);
	GetArrayArray(g_Array_angData, locationNum - 1, ang);
	GetArrayArray(g_Array_velData, locationNum - 1, vel);

	if ((GetVectorDistance(pos, NULL_VECTOR) > 0.00) && (GetVectorDistance(ang, NULL_VECTOR) > 0.00))
	{
		float newVel[3];
		TeleportEntity(client, pos, ang, vel);
		GetClientVelocity(client, newVel);

		// TODO: figure out if there's a better way to do this
		// when initiating a teleport, save their loc number
		if (locationNum != g_Int_currentLoc[client])
		{
			g_Int_currentLoc[client] = locationNum;
			PrintToChat(client, "%sLoaded location #%d.", g_chatTag, locationNum);
		}

		// debug
		// PrintToConsole(client, "tele vel: %f, %f, %f", vel[0],vel[1],vel[2]);
	}
	else	// print error and exit
	{
		PrintToChat(client, "%sNo Saveloc found.", g_chatTag);
	}
}

// Forwards
public OnMapEnd()
{
	resetData();
}

public OnClientPutInServer(int client)
{
	clearClientLoc(client);
}

public OnClientDisconnect(int client)
{
	clearClientLoc(client);
}

// Utility
clearClientLoc(int client)
{
	g_Int_currentLoc[client] = 0;
}

GetClientVelocity(client, float vel[3])
{
	// dig into the entity properties for the client
	vel[0] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
	vel[1] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");
	vel[2] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[2]");
}


resetData()
{
	ClearArray(g_Array_posData);
	ClearArray(g_Array_angData);
	ClearArray(g_Array_velData);
	locCount = 0;
}
