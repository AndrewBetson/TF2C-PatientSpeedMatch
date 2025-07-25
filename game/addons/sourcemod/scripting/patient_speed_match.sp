// SPDX-FileCopyrightText: © Andrew Betson
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <dhooks>
#include <sdktools>
#include <tf2c>

#pragma semicolon 1
#pragma newdecls required

#if !defined PLUGIN_VERSION
#define PLUGIN_VERSION "1.1.0"
#endif // !defined PLUGIN_VERSION

DHookSetup gDetour_CWeaponMedigun_HealTargetThink;
float gDefaultMaxSpeed[ MAXPLAYERS+1 ] = { 0.0, ... };
ConVar psm_match_shield_charge;

public Plugin myinfo =
{
	name		= "[TF2C] Patient Speed Match",
	description	= "Medics match their patient's speed if it is greater than their own",
	author		= "Andrew \"andrewb\" Betson",
	version		= PLUGIN_VERSION,
	url			= "https://www.github.com/AndrewBetson/TF2C-PatientSpeedMatch/"
};

public void OnPluginStart()
{
	Handle GData = LoadGameConfigFile( "patient_speed_match.games" );
	if ( !GData )
	{
		SetFailState( "Failed to load patient_speed_match gamedata." );
	}

	gDetour_CWeaponMedigun_HealTargetThink = DHookCreateFromConf( GData, "CWeaponMedigun::HealTargetThink" );

	delete GData;

	if ( !DHookEnableDetour( gDetour_CWeaponMedigun_HealTargetThink, false, Detour_CWeaponMedigun_HealTargetThink ) )
	{
		SetFailState( "Failed to detour CWeaponMedigun::HealTargetThink, tell Andrew to update the signatures." );
	}

	psm_match_shield_charge = CreateConVar(
		"psm_match_shield_charge",
		"0",
		"Match speed of players charging with shields",
		FCVAR_NONE,
		true, 0.0,
		true, 1.0
	);

	HookEvent( "post_inventory_application", Event_PostInventoryApplication );
}

public void Event_PostInventoryApplication( Event Evt, const char[] Name, bool bDontBroadcast )
{
	// Cache-off player's default max speed
	// to compare against in HealTargetThink.
	//
	// We do this in post_inventory_application
	// in case we're being used by a server
	// that has custom weapons that change
	// Medic's max speed.

	int Client = GetClientOfUserId( Evt.GetInt( "userid" ) );
	gDefaultMaxSpeed[ Client ] = GetEntPropFloat( Client, Prop_Send, "m_flMaxspeed" );
}

public MRESReturn Detour_CWeaponMedigun_HealTargetThink( int This, DHookReturn Return, DHookParam Params )
{
	int Medic = GetEntPropEnt( This, Prop_Send, "m_hOwnerEntity" );
	int Patient = GetEntPropEnt( This, Prop_Send, "m_hHealingTarget" );

	// These shouldn't be possible, but just in case...
	if ( !IsClientInGame( Patient ) || !IsPlayerAlive( Patient ) )
	{
		return MRES_Ignored;
	}

	bool bIsMedicCharging = TF2_IsPlayerInCondition( Medic, TFCond_Charging );
	bool bIsPatientCharging = TF2_IsPlayerInCondition( Patient, TFCond_Charging );

	// Only match the speed of shield-charging patients
	// if we're allowed to do so.
	if ( bIsPatientCharging )
	{
		if ( psm_match_shield_charge.BoolValue && !bIsMedicCharging )
		{
			// Make the Medic start charging to match.
			TF2_AddCondition( Medic, TFCond_Charging );
		}

		return MRES_Ignored;
	}
	else if ( bIsMedicCharging )
	{
		// Make the Medic stop charging if the patient's charge has run out.
		TF2_RemoveCondition( Medic, TFCond_Charging );
		return MRES_Ignored;
	}

	float MedicMaxSpeed = gDefaultMaxSpeed[ Medic ];
	float PatientMaxSpeed = GetEntPropFloat( Patient, Prop_Send, "m_flMaxspeed" );

	// Only match the patient's speed if it's
	// greater than this Medic's default max speed.
	if ( PatientMaxSpeed > MedicMaxSpeed )
	{
		SetEntPropFloat( Medic, Prop_Send, "m_flMaxspeed", PatientMaxSpeed );
	}

	return MRES_Ignored;
}
