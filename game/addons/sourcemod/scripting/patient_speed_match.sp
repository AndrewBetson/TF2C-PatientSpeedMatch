// SPDX-FileCopyrightText: © Andrew Betson
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <dhooks>
#include <sdktools>
#include <tf2c>

#pragma semicolon 1
#pragma newdecls required

#if !defined PLUGIN_VERSION
#define PLUGIN_VERSION "1.0.0"
#endif // !defined PLUGIN_VERSION

DHookSetup gDetour_CWeaponMedigun_HealTargetThink;

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

	// We get this each time instead of just
	// using a constant w/ Medic's default
	// max speed in case servers that mess
	// with class speeds use this plugin.
	float MedicMaxSpeed = GetEntPropFloat( Medic, Prop_Send, "m_flMaxspeed" );

	float PatientMaxSpeed = GetEntPropFloat( Patient, Prop_Send, "m_flMaxspeed" );

	SetEntPropFloat( Medic, Prop_Send, "m_flMaxspeed", PatientMaxSpeed > MedicMaxSpeed ? PatientMaxSpeed : MedicMaxSpeed );

	return MRES_Ignored;
}
