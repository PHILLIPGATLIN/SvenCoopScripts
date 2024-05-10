// designed and written by Phillip aka The White Lion
// 10 February 2024
// This script codes for a basic power-up item class, and implements some examples of power-up items as entities
// How to use them: each power up class is named like item_power_[class name], add an entity to your map with the name of one of the entity class names e.g. "item_power_levitate" and YOU SHOULD set a key value named "Respawn" to either "Yes" or "No" to define respawn behavior
// this script file features 10 unique power ups and they are all functional
// you can use some helper functions to spawn random power ups in your map, they are CreateRandomPower() and CreateWeightedRandomCombatPower()
// also it is ESSENTIAL you include this script code in your map script:
/*
void MapInit()
{	
	SvenCoopPower::Register();

	// haste needs this to happen
	// these are essential for proper behavior, all maps that use SvenCoopPower must have these statements in their MapInit()
	g_EngineFuncs.CVarSetFloat( "sv_maxspeed", 540 );
	g_Hooks.RegisterHook( Hooks::Player::ClientPutInServer, @CItemPowerManager_HasteSetBaseSpeed );
	g_Hooks.RegisterHook( Hooks::Player::PlayerSpawn, @CItemPowerManager_HasteSetBaseSpeed );
	
	return;
}
*/

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "The White Lion" );
	g_Module.ScriptInfo.SetContactInfo( "Discord: thewhitelion, Steam: https://steamcommunity.com/id/7H3WH143L10N/" );
}

namespace SvenCoopPower
{	
	// the CBasePlayer class has field variables that can be used to implement power-up behavior
	// I think I don't need to implement an item_inventory class to apply these player effects
	class CItemPower : ScriptBaseItemEntity
	{
		protected string m_sModel; // this field is designed to be customized
		protected string m_sSoundFX_Pickup; // this field is designed to be customized
		protected string m_sSoundFX_Spawn = "items/suitchargeok1.wav";
		protected float m_fRespawnTime; // this field is designed to be customized
		protected bool m_bRespawn = false; // this field is designed to be customized
		protected float m_fDuration; // this field is designed to be customized
		protected Vector m_vInitialOrigin; // this is used to store the origin of the entity when it spawns in the map for the animated floating effects
		private bool m_bKeyvalueSet = false;
		private float m_fLifeTime = 15.0f;
		private float m_fBirthTime;
		
		bool KeyValue( const string& in szKey, const string& in szValue )
		{
			if ( szKey == "Respawn" )
			{
				m_bRespawn = ( szValue == "Yes" || atoi( szValue ) == 1 ? true : false );
				m_bKeyvalueSet = true;
			}
			
			return BaseClass.KeyValue( szKey, szValue );
		}
		
		void Precache()
		{
			g_Game.PrecacheModel( m_sModel );
			g_SoundSystem.PrecacheSound( m_sSoundFX_Pickup );
			g_SoundSystem.PrecacheSound( m_sSoundFX_Spawn );
			
			return;
		}
		
		void PowerSpawn()
		{
			Precache();
			
			g_EntityFuncs.SetModel(self, m_sModel);
			
			g_EntityFuncs.SetSize( self.pev, /*min*/ Vector(-8,-8,-8), /*max*/ Vector(8,8,8) ); // 16x16x16
			
			self.pev.movetype = MOVETYPE_FLY;
			self.pev.solid = SOLID_TRIGGER;
			
			if ( m_bKeyvalueSet == false ) m_bRespawn = false;
			
			self.pev.nextthink = g_Engine.time;
			
			if ( !m_bRespawn ) g_Scheduler.SetTimeout( "CItemPowerManager_Delete", m_fLifeTime, EHandle(self) );
			
			return;
		}
		
		void PowerTouch(CBaseEntity@ pOther)
		{
			if ( pOther is null) return;
			if ( !pOther.IsPlayer() ) return;
			if ( pOther.pev.health <= 0 ) return;
			
			CBasePlayer@ pPlayer = cast<CBasePlayer@>(pOther);
			
			//CustomKeyvalues@ pKeyValues = pPlayer.GetCustomKeyvalues();
			//if ( pKeyValues is null ) g_Game.AlertMessage( at_console, "INFO: pKeyValues is null!\n" );
			
			//CustomKeyvalue value( pKeyValues.GetKeyvalue("%s_HasPowerUp") );
			
			/*if ( value.Exists() )
			{
				if ( value.GetString() == "YES" ) return;
			}*/
			
			//pKeyValues.SetKeyvalue( "%s_HasPowerUp", "YES" );
			
			// Apply power-up effect
			PowerUP(pPlayer);
			g_SoundSystem.EmitSound( pPlayer.edict(), CHAN_ITEM, m_sSoundFX_Pickup, 1.0, ATTN_NORM );
			
			g_Game.AlertMessage( at_console, "INFO: m_bRespawn value is %1\n", m_bRespawn ? string("true") : string("false") );
			if ( m_bRespawn == false ) 
			{
				Die();
				
				return;
			}
			
			SetTouch(null);
			SetThink(null);
			self.pev.effects |= EF_NODRAW;
			g_Scheduler.SetTimeout( "CItemPowerManager_Respawn", m_fRespawnTime, cast<CItemPower@>( CastToScriptClass( self ) ) );
			
			return;
		}
		
		// in the current design this function must be implemented in the child class
		// this is necessary so the child class can set the correct Touch/Think functions
		void Respawn() {}
		
		void PowerThink()
		{
			// this code may not be necessary if the model file features these kind of animated effects
			
			
			
			// SPEEN, UP-DOWN
			self.pev.angles.y += 5.00f;
			self.pev.origin.z += (sin(g_Engine.time)) * 0.5; // this can make the pickup fall through the floor if it is picked up at the low range of sine(x)
			self.pev.nextthink = g_Engine.time + 0.05;
			
			return;
		}
		
		void PowerUP(CBasePlayer@ pPlayer) {} // apply the power-up effect to the player, must be implemented in child classes
		
		void PowerDOWN(CBasePlayer@ pPlayer) {} // remove the power-up effecet from the player, must be implemented in child classes
		
		void Die()
		{
			g_EntityFuncs.Remove( self );
			
			return;
		}
		
		void PowerUPGFXOn(Vector colour, CBasePlayer@ pPlayer)
		{
			// dynamic light effect
			NetworkMessage nmsgA( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY, null );
				nmsgA.WriteByte( TE_DLIGHT ); // type
				nmsgA.WriteCoord( pPlayer.pev.origin.x ); // location, x
				nmsgA.WriteCoord( pPlayer.pev.origin.y ); // location, y
				nmsgA.WriteCoord( pPlayer.pev.origin.z ); // location, z
				nmsgA.WriteByte( 32 ); // extent of the light
				nmsgA.WriteByte( int(colour.x) ); // color value R
				nmsgA.WriteByte( int(colour.y) ); // color value G
				nmsgA.WriteByte( int(colour.z) ); // color value B
				nmsgA.WriteByte( int(m_fDuration) ); // lifetime of the light source
				nmsgA.WriteByte( 35 ); // decay rate, rate of vanishing
			nmsgA.End();
			
			// implosion effect
			NetworkMessage nmsgB( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY, null );
				nmsgB.WriteByte( TE_IMPLOSION );
				nmsgB.WriteCoord( pPlayer.pev.origin.x );
				nmsgB.WriteCoord( pPlayer.pev.origin.y );
				nmsgB.WriteCoord( pPlayer.pev.origin.z );
				nmsgB.WriteByte( 255 );
				nmsgB.WriteByte( 32 );
				nmsgB.WriteByte( 5 );
			nmsgB.End();
			
			// glow shell effect
			// for some reason these are the correct field variables to set to apply a glow shell to the player. OK, whatever works.
			pPlayer.m_iOriginalRenderMode = kRenderNormal;
			pPlayer.m_iOriginalRenderFX = kRenderFxGlowShell;
			pPlayer.m_flOriginalRenderAmount = 4;
			pPlayer.m_vecOriginalRenderColor = colour;
			
			return;
		}
		
		void PowerUPGFXOff(CBasePlayer@ pPlayer)
		{
			// remove glow shell effect
			pPlayer.m_iOriginalRenderMode = kRenderNormal;
			pPlayer.m_iOriginalRenderFX = kRenderFxNone;
			pPlayer.m_flOriginalRenderAmount = 0;
			pPlayer.m_vecOriginalRenderColor = Vector(0,0,0);
			
			return;
		}
		
	}
	
	// don't override Touch() or Think() in these child classes, they depend on the baseclass implementation
	// all specific power up classes need to schedule a function to remove the power up effect from the player
	// #1
	class CItemPower_Levitate : CItemPower	// makes player float
	{
		private Vector LevitateColor = Vector( 82, 230, 250 ); // like turqoise blue
		
		CItemPower_Levitate()
		{
			// assigning a value to these member variables is critically important for Precache() in the base class else precache will fail and the code will break
			m_sModel = "models/common/lambda.mdl"; // this is meant to be a substitute model for when there is original models
			m_sSoundFX_Pickup = "ambience/particle_suck1.wav";
			m_fRespawnTime = 10.0f;
			m_fDuration = 15.0f;
		}
		
		void Spawn()
		{
			PowerSpawn();
			
			SetTouch( TouchFunction(this.LevitateTouch) );
			SetThink( ThinkFunction(this.LevitateThink) );
			
			self.pev.rendermode = kRenderNormal;
			self.pev.renderfx = kRenderFxGlowShell;
			self.pev.renderamt = 32;
			self.pev.rendercolor = LevitateColor;
			
			m_vInitialOrigin = self.pev.origin;
			
			return;
		}
		
		void Respawn() override
		{
			// make the entity interactable again
			// schedule think
			// play respawn sound
			
			self.pev.origin = m_vInitialOrigin;
			
			self.pev.effects ^= EF_NODRAW;
			self.pev.solid = SOLID_TRIGGER;
			SetTouch( TouchFunction(this.LevitateTouch) );
			SetThink( ThinkFunction(this.LevitateThink) );
			
			g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, m_sSoundFX_Spawn, 1.0, ATTN_NORM );
			
			self.pev.nextthink = g_Engine.time;
			
			return;
		}
		
		void PowerUP(CBasePlayer@ pPlayer) override
		{
			PowerUPGFXOn( LevitateColor, pPlayer);
			
			// apply the levitation effect
			pPlayer.m_flEffectGravity = 0.001f;
			pPlayer.ApplyEffects();
			
			g_Scheduler.SetTimeout( @CItemPower_Levitate(), "PowerDOWN", m_fDuration, @pPlayer );
			
			return;
		}
		
		void PowerDOWN(CBasePlayer@ pPlayer) override
		{
			PowerUPGFXOff(pPlayer);
					
			pPlayer.ResetEffects();
			pPlayer.ApplyEffects();
			
			return;
		}
		
		void LevitateTouch(CBaseEntity@ pOther)
		{
			CItemPower::PowerTouch(pOther);
			
			return;
		}
		
		void LevitateThink()
		{
			CItemPower::PowerThink();
			
			return;
		}
		
	}
	// #2, this one works but it's kind of meh. A little tricky to control and the player is vulnerable to fall damage.
	//     In the future I am going to implement a hook to trigger the jump effect and make the player immune to fall damage.
	class CItemPower_HighJump : CItemPower // makes the player jump higher
	{
		// for some reason the game doesn't draw this color as a glow shell for a player...
		private Vector HighJumpColor = Vector( 240, 35, 230 ); // hot pink
		private string m_sSoundFX_Effect;
		
		CItemPower_HighJump()
		{
			m_sModel = "models/common/lambda.mdl";
			m_sSoundFX_Pickup = "ambience/particle_suck2.wav";
			m_sSoundFX_Effect = "ambience/alien_humongo.wav";
			m_fRespawnTime = 10.0f;
			m_fDuration = 5.5f;
		}
		
		void Spawn()
		{
			PowerSpawn();
			
			g_SoundSystem.PrecacheSound( m_sSoundFX_Effect );
			
			SetTouch( TouchFunction(this.HighJumpTouch) );
			SetThink( ThinkFunction(this.HighJumpThink) );
			
			self.pev.rendermode = kRenderNormal;
			self.pev.renderfx = kRenderFxGlowShell;
			self.pev.renderamt = 32;
			self.pev.rendercolor = HighJumpColor;
			
			m_vInitialOrigin = self.pev.origin; // I think at this point the Think function hasn't been called yet...
			
			return;
		}
		
		void Respawn() override
		{
			// make the entity interactable again
			// schedule think
			// play respawn sound
			
			self.pev.origin = m_vInitialOrigin; // powerups are not supposed to move around the map
			
			self.pev.effects ^= EF_NODRAW;
			self.pev.solid = SOLID_TRIGGER;
			SetTouch( TouchFunction(this.HighJumpTouch) );
			SetThink( ThinkFunction(this.HighJumpThink) );
			
			g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, m_sSoundFX_Spawn, 1.0, ATTN_NORM );
			
			self.pev.nextthink = g_Engine.time;
			
			return;
		}
		
		
		void PowerUP( CBasePlayer@ pPlayer ) override
		{
			PowerUPGFXOn( Vector(0,0,0), pPlayer );
			
			g_Scheduler.SetTimeout( "CItemPowerManager_HighJump", m_fDuration - 0.5f, @pPlayer );
			g_Scheduler.SetTimeout( this, "JumpSFX", m_fDuration - 0.5f );
			g_Scheduler.SetTimeout( @CItemPower_HighJump(), "PowerDOWN", m_fDuration, @pPlayer );
			
			return;
		}
		
		void JumpSFX()
		{
			g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, m_sSoundFX_Effect, 1.0, ATTN_NORM );
			
			return;
		}
		
		void PowerDOWN( CBasePlayer@ pPlayer ) override
		{
			PowerUPGFXOff(pPlayer);
			
			//g_MikkHooks.RemoveHook( Hooks::Player::PlayerKeyInput, @PlayerKeyInput );
			
			pPlayer.ResetEffects();
			pPlayer.ApplyEffects();
			
			return;
		}
		
		void HighJumpTouch( CBaseEntity@ pOther )
		{
			CItemPower::PowerTouch(pOther);
			
			return;
		}
		
		void HighJumpThink()
		{
			CItemPower::PowerThink();
			
			return;
		}
		
	}
	// #3
	class CItemPower_Invincible : CItemPower // immune to damage
	{
		private Vector InvincibleColor = Vector( 255, 168, 38 ); // orange
		
		CItemPower_Invincible()
		{
			m_sModel = "models/common/lambda.mdl";
			m_sSoundFX_Pickup = "ambience/particle_suck1.wav";
			m_fRespawnTime = 10.0f;
			m_fDuration = 10.0f;
		}
		
		
		void Spawn()
		{
			PowerSpawn();
			
			SetTouch( TouchFunction(this.InvincibleTouch) );
			SetThink( ThinkFunction(this.InvincibleThink) );
			
			self.pev.rendermode = kRenderNormal;
			self.pev.renderfx = kRenderFxGlowShell;
			self.pev.renderamt = 32;
			self.pev.rendercolor = InvincibleColor;
			
			m_vInitialOrigin = self.pev.origin; // I think at this point the Think function hasn't been called yet...
			
			return;
		}
		
		void Respawn() override
		{
			// make the entity interactable again
			// schedule think
			// play respawn sound
			
			self.pev.origin = m_vInitialOrigin;
			
			self.pev.effects ^= EF_NODRAW;
			self.pev.solid = SOLID_TRIGGER;
			SetTouch( TouchFunction(this.InvincibleTouch) );
			SetThink( ThinkFunction(this.InvincibleThink) );
			
			g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, m_sSoundFX_Spawn, 1.0, ATTN_NORM );
			
			self.pev.nextthink = g_Engine.time;
			
			return;
		}
		
		void PowerUP( CBasePlayer@ pPlayer ) override
		{
			PowerUPGFXOn( InvincibleColor, pPlayer );
			
			++pPlayer.m_iEffectInvulnerable;
			pPlayer.ApplyEffects();
			
			g_Scheduler.SetTimeout( @CItemPower_Invincible(), "PowerDOWN", m_fDuration, @pPlayer );
			
			return;
		}
		
		void PowerDOWN( CBasePlayer@ pPlayer ) override
		{
			PowerUPGFXOff(pPlayer);
			
			pPlayer.ResetEffects();
			pPlayer.ApplyEffects();
			
			return;
		}
		
		void InvincibleTouch(CBaseEntity@ pOther)
		{
			CItemPower::PowerTouch( pOther );
			
			return;
		}
		
		void InvincibleThink()
		{
			CItemPower::PowerThink();
			
			return;
		}
	}
	// #4
	class CItemPower_Ghost : CItemPower // player no touch, as far as I can tell this effect makes players not trigger the trigger effects of trigger solids
										// which is kind of lame...maybe combine this with invisibility?
										// it's kind of lame, but it could be useful...
	{
		private Vector GhostColor = Vector( 255, 255, 255 ); // pure white
		
		CItemPower_Ghost()
		{
			m_sModel = "models/common/lambda.mdl";
			m_sSoundFX_Pickup = "ambience/particle_suck1.wav";
			m_fRespawnTime = 10.0f;
			m_fDuration = 10.0f;
		}
		
		void Spawn()
		{
			PowerSpawn();
			
			SetTouch( TouchFunction(this.GhostTouch) );
			SetThink( ThinkFunction(this.GhostThink) );
			
			self.pev.rendermode = kRenderNormal;
			self.pev.renderfx = kRenderFxGlowShell;
			self.pev.renderamt = 32;
			self.pev.rendercolor = GhostColor;
			
			m_vInitialOrigin = self.pev.origin; // I think at this point the Think function hasn't been called yet...
			
			return;
		}
		
		void Respawn() override
		{
			// make the entity interactable again
			// schedule think
			// play respawn sound
			
			self.pev.origin = m_vInitialOrigin;
			
			self.pev.effects ^= EF_NODRAW;
			self.pev.solid = SOLID_TRIGGER;
			SetTouch( TouchFunction(this.GhostTouch) );
			SetThink( ThinkFunction(this.GhostThink) );
			
			g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, m_sSoundFX_Spawn, 1.0, ATTN_NORM );
			
			self.pev.nextthink = g_Engine.time;
			
			return;
		}
		
		void GhostTouch(CBaseEntity@ pOther)
		{
			CItemPower::PowerTouch(pOther);
			
			return;
		}
		
		void GhostThink()
		{
			CItemPower::PowerThink();
			
			return;
		}
		
		void PowerUP( CBasePlayer@ pPlayer ) override
		{
			PowerUPGFXOn( Vector(0,0,0), pPlayer );
			
			++pPlayer.m_iEffectNonSolid;
			++pPlayer.m_iEffectInvisible;
			pPlayer.ApplyEffects();
			
			g_Scheduler.SetTimeout( @CItemPower_Ghost(), "PowerDOWN", m_fDuration, @pPlayer );
			
			return;
		}
		
		void PowerDOWN( CBasePlayer@ pPlayer ) override
		{
			PowerUPGFXOff(pPlayer);
			
			pPlayer.ResetEffects();
			pPlayer.ApplyEffects();
			
			return;
		}
	}
	// #5
	class CItemPower_Amphibian : CItemPower // breath underwater
	{
		private Vector AmphibianColor = Vector( 34, 179, 39 ); // light lime green
		
		CItemPower_Amphibian()
		{
			m_sModel = "models/common/lambda.mdl";
			m_sSoundFX_Pickup = "ambience/particle_suck1.wav";
			m_fRespawnTime = 10.0f;
			m_fDuration = 55.0f;
		}
		
		void Spawn()
		{
			PowerSpawn();
			
			SetTouch( TouchFunction(this.AmphibianTouch) );
			SetThink( ThinkFunction(this.AmphibianThink) );
			
			self.pev.rendermode = kRenderNormal;
			self.pev.renderfx = kRenderFxGlowShell;
			self.pev.renderamt = 32;
			self.pev.rendercolor = AmphibianColor;
			
			m_vInitialOrigin = self.pev.origin; // I think at this point the Think function hasn't been called yet...
			
			return;
		}
		
		void Respawn() override
		{
			// make the entity interactable again
			// schedule think
			// play respawn sound
			
			self.pev.origin = m_vInitialOrigin;
			
			self.pev.effects ^= EF_NODRAW;
			self.pev.solid = SOLID_TRIGGER;
			SetTouch( TouchFunction(this.AmphibianTouch) );
			SetThink( ThinkFunction(this.AmphibianThink) );
			
			g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, m_sSoundFX_Spawn, 1.0, ATTN_NORM );
			
			self.pev.nextthink = g_Engine.time;
			
			return;
		}
		
		void AmphibianTouch( CBaseEntity@ pOther )
		{
			CItemPower::PowerTouch( pOther );
			
			return;
		}
		
		void AmphibianThink()
		{
			CItemPower::PowerThink();
			
			return;
		}
		
		void PowerUP( CBasePlayer@ pPlayer ) override
		{
			PowerUPGFXOn( AmphibianColor, pPlayer );
			
			pPlayer.m_flEffectRespiration = m_fDuration;
			pPlayer.ApplyEffects();
			
			g_Scheduler.SetTimeout( @CItemPower_Amphibian(), "PowerDOWN", m_fDuration, @pPlayer );
			
			return;
		}
		
		void PowerDOWN( CBasePlayer@ pPlayer ) override
		{
			PowerUPGFXOff(pPlayer);
			
			pPlayer.ResetEffects();
			pPlayer.ApplyEffects();
			
			return;
		}
	}
	// #6
	class CItemPower_Invisibility : CItemPower // player invisible, but also makes them not targetable by NPCs
	{
		private Vector InvisibilityColor = Vector( 224, 243, 255 ); // mostly white with a touch of blueness
		
		CItemPower_Invisibility()
		{
			m_sModel = "models/common/lambda.mdl";
			m_sSoundFX_Pickup = "ambience/particle_suck1.wav";
			m_fRespawnTime = 10.0f;
			m_fDuration = 15.0f;
		}
		
		void Spawn()
		{
			PowerSpawn();
			
			SetTouch( TouchFunction(this.InvisibilityTouch) );
			SetThink( ThinkFunction(this.InvisibilityThink) );
			
			self.pev.rendermode = kRenderNormal;
			self.pev.renderfx = kRenderFxGlowShell;
			self.pev.renderamt = 32;
			self.pev.rendercolor = InvisibilityColor;
			
			m_vInitialOrigin = self.pev.origin; // I think at this point the Think function hasn't been called yet...
			
			return;
		}
		
		void Respawn() override
		{
			// make the entity interactable again
			// schedule think
			// play respawn sound
			
			self.pev.origin = m_vInitialOrigin;
			
			self.pev.effects ^= EF_NODRAW;
			self.pev.solid = SOLID_TRIGGER;
			SetTouch( TouchFunction(this.InvisibilityTouch) );
			SetThink( ThinkFunction(this.InvisibilityThink) );
			
			g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, m_sSoundFX_Spawn, 1.0, ATTN_NORM );
			
			self.pev.nextthink = g_Engine.time;
			
			return;
		}
		
		void InvisibilityTouch( CBaseEntity@ pOther )
		{
			CItemPower::PowerTouch(pOther);
			
			return;
		}

		void InvisibilityThink()
		{
			CItemPower::PowerThink();
			
			return;
		}
		
		void PowerUP( CBasePlayer@ pPlayer ) override
		{
			PowerUPGFXOn( InvisibilityColor, pPlayer );
			
			++(pPlayer.m_iEffectInvisible);
			pPlayer.ApplyEffects();
			
			g_Scheduler.SetTimeout( @CItemPower_Invisibility(), "PowerDOWN", m_fDuration, @pPlayer );
			
			return;
		}
		
		void PowerDOWN( CBasePlayer@ pPlayer ) override
		{
			PowerUPGFXOff(pPlayer);
			
			pPlayer.ResetEffects();
			pPlayer.ApplyEffects();
			
			// custom GFX when effect finishes
			NetworkMessage nmsg( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY, null );
				nmsg.WriteByte( TE_TELEPORT );
				nmsg.WriteCoord( pPlayer.pev.origin.x );
				nmsg.WriteCoord( pPlayer.pev.origin.y );
				nmsg.WriteCoord( pPlayer.pev.origin.z );
			nmsg.End();
			
			return;
		}
	}
	// #7
	class CItemPower_Haste : CItemPower // player run really fast. this one doesn't work! hmm...UPDATE: this really does work, but you have to increase the value of sv_maxspeed
	{
		private Vector HasteColor = Vector( 244, 255, 36 ); // yellow
		
		CItemPower_Haste()
		{
			m_sModel = "models/common/lambda.mdl";
			m_sSoundFX_Pickup = "ambience/particle_suck1.wav";
			m_fRespawnTime = 10.0f;
			m_fDuration = 15.0f;
		}
		
		void Spawn()
		{
			PowerSpawn();
			
			SetTouch( TouchFunction(this.HasteTouch) );
			SetThink( ThinkFunction(this.HasteThink) );
			
			self.pev.rendermode = kRenderNormal;
			self.pev.renderfx = kRenderFxGlowShell;
			self.pev.renderamt = 32;
			self.pev.rendercolor = HasteColor;
			
			m_vInitialOrigin = self.pev.origin; // I think at this point the Think function hasn't been called yet...
			
			return;
		}
		
		void Respawn() override
		{
			// make the entity interactable again
			// schedule think
			// play respawn sound
			
			self.pev.origin = m_vInitialOrigin;
			
			self.pev.effects ^= EF_NODRAW;
			self.pev.solid = SOLID_TRIGGER;
			SetTouch( TouchFunction(this.HasteTouch) );
			SetThink( ThinkFunction(this.HasteThink) );
			
			g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, m_sSoundFX_Spawn, 1.0, ATTN_NORM );
			
			self.pev.nextthink = g_Engine.time;
			
			return;
		}
		
		void Die()
		{	
			CItemPower::Die();
			
			return;
		}
		
		void HasteTouch( CBaseEntity@ pOther )
		{
			CItemPower::PowerTouch( pOther );
			
			return;
		}
		
		void HasteThink()
		{
			CItemPower::PowerThink();
			
			return;
		}
		
		void PowerUP( CBasePlayer@ pPlayer ) override
		{
			PowerUPGFXOn( HasteColor, pPlayer );
			
			pPlayer.m_flEffectSpeed = 2.00f; 
			pPlayer.ApplyEffects();
			
			// i think the only way to make this powerup work is to increase the value of sv_maxspeed
			// what makes doing this a problem is that sv_maxspeed has a global effect for all players
			// i think what i can do is set the value of sv_maxspeed when the map is initialized but then i must set the speed of ALL players to a base value
			// i wish it were easier...but this may be the way to do it.
			// actually i think i won't be able to get a reference to any player when a map is initialized
			// i could implement a hook function to set the speed of a player to the base value when that player connects
			// so there are two hooks, one when the client is put into the server and one when a player respawns
			// in both cases the player speed is set to the base value of 270, this is the normal speed for the Sven Coop player 
			
			g_Scheduler.SetTimeout( @CItemPower_Haste(), "PowerDOWN", m_fDuration, @pPlayer );
			
			return;
		}
		
		void PowerDOWN( CBasePlayer@ pPlayer ) override
		{
			PowerUPGFXOff(pPlayer);
			
			pPlayer.ResetEffects();
			pPlayer.ApplyEffects();
			
			return;
		}
	}
	// #8
	class CItemPower_DoubleDamage : CItemPower // player does double damage with all weapons
	{
		private Vector DoubleDamageColor = Vector( 255, 25, 25 ); // red
		
		CItemPower_DoubleDamage()
		{
			m_sModel = "models/common/lambda.mdl";
			m_sSoundFX_Pickup = "ambience/particle_suck1.wav";
			m_fRespawnTime = 12.0f;
			m_fDuration = 10.0f;
		}
		
		void Spawn()
		{
			PowerSpawn();
			
			SetTouch( TouchFunction(this.DoubleDamageTouch) );
			SetThink( ThinkFunction(this.DoubleDamageThink) );
			
			self.pev.rendermode = kRenderNormal;
			self.pev.renderfx = kRenderFxGlowShell;
			self.pev.renderamt = 32;
			self.pev.rendercolor = DoubleDamageColor;
			
			m_vInitialOrigin = self.pev.origin; // I think at this point the Think function hasn't been called yet...
			
			return;
		}
		
		void Respawn() override
		{
			// make the entity interactable again
			// schedule think
			// play respawn sound
			
			self.pev.origin = m_vInitialOrigin;
			
			self.pev.effects ^= EF_NODRAW;
			self.pev.solid = SOLID_TRIGGER;
			SetTouch( TouchFunction(this.DoubleDamageTouch) );
			SetThink( ThinkFunction(this.DoubleDamageThink) );
			
			g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, m_sSoundFX_Spawn, 1.0, ATTN_NORM );
			
			self.pev.nextthink = g_Engine.time;
			
			return;
		}
		
		void DoubleDamageTouch( CBaseEntity@ pOther )
		{
			CItemPower::PowerTouch( pOther );
			
			return;
		}
		
		void DoubleDamageThink()
		{
			CItemPower::PowerThink();
			
			return;
		}
		
		void PowerUP( CBasePlayer@ pPlayer ) override
		{
			PowerUPGFXOn( DoubleDamageColor, pPlayer );
			
			pPlayer.m_flEffectDamage = 2.0f;// this value is supposed to be a percentage
			pPlayer.ApplyEffects();
			
			g_Scheduler.SetTimeout( @CItemPower_DoubleDamage(), "PowerDOWN", m_fDuration, @pPlayer );
			
			return;
		}
		
		void PowerDOWN( CBasePlayer@ pPlayer ) override
		{
			PowerUPGFXOff(pPlayer);
			
			pPlayer.ResetEffects();
			pPlayer.ApplyEffects();
			
			return;
		}
	}
	// #9
	class CItemPower_AmmoRegeneration : CItemPower // continuously adds ammo to the player's weapon clip for any weapon that uses ammo
												   // not all weapons use ammo clips!!!
												   // makes the game crash T_T
												   // not anymore!
	{
		private Vector AmmoRegenerationColor = Vector( 174, 0, 255 ); // purple
		private CScheduledFunction@ queuedfunc;
		
		CItemPower_AmmoRegeneration()
		{
			m_sModel = "models/common/lambda.mdl";
			m_sSoundFX_Pickup = "ambience/particle_suck1.wav";
			m_fRespawnTime = 10.0f;
			m_fDuration = 15.0f;
		}
		
		CItemPower_AmmoRegeneration( const CItemPower_AmmoRegeneration &in other ) // copy constructor
		{
			@queuedfunc = @other.queuedfunc;
		}
		
		void Spawn()
		{
			PowerSpawn();
			
			SetTouch( TouchFunction(this.AmmoRegenerationTouch) );
			SetThink( ThinkFunction(this.AmmoRegenerationThink) );
			
			self.pev.rendermode = kRenderNormal;
			self.pev.renderfx = kRenderFxGlowShell;
			self.pev.renderamt = 32;
			self.pev.rendercolor = AmmoRegenerationColor;
			
			m_vInitialOrigin = self.pev.origin; // I think at this point the Think function hasn't been called yet...
			
			return;
		}
		
		void Respawn() override
		{
			// make the entity interactable again
			// schedule think
			// play respawn sound
			
			self.pev.origin = m_vInitialOrigin;
			
			self.pev.effects ^= EF_NODRAW;
			self.pev.solid = SOLID_TRIGGER;
			SetTouch( TouchFunction(this.AmmoRegenerationTouch) );
			SetThink( ThinkFunction(this.AmmoRegenerationThink) );
			
			g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, m_sSoundFX_Spawn, 1.0, ATTN_NORM );
			
			self.pev.nextthink = g_Engine.time;
			
			return;
		}
		
		void AmmoRegenerationTouch( CBaseEntity@ pOther )
		{
			CItemPower::PowerTouch( pOther );
			
			return;
		}
		
		void AmmoRegenerationThink()
		{
			CItemPower::PowerThink();
			
			return;
		}
		
		void PowerUP( CBasePlayer@ pPlayer ) override
		{
			PowerUPGFXOn( AmmoRegenerationColor, pPlayer );
			
			pPlayer.ApplyEffects();
			
			@queuedfunc = g_Scheduler.SetInterval("CItemPowerManager_AmmoRegen", 2.0f, g_Scheduler.REPEAT_INFINITE_TIMES, @pPlayer);
			g_Scheduler.SetTimeout( @CItemPower_AmmoRegeneration(this), "PowerDOWN", m_fDuration, @pPlayer );
			
			return;
		}
		
		void PowerDOWN( CBasePlayer@ pPlayer ) override
		{
			PowerUPGFXOff( pPlayer );
			
			pPlayer.ResetEffects();
			pPlayer.ApplyEffects();
			
			g_Scheduler.RemoveTimer( queuedfunc );
			
			return;
		}
	}
	// #10
	class CItemPower_Vitality : CItemPower // makes your max HP equal to 500, it works nicely.
	{
		private Vector VitalityColor = Vector( 157, 255, 0 ); // a yellow green
		
		CItemPower_Vitality()
		{
			m_sModel = "models/common/lambda.mdl";
			m_sSoundFX_Pickup = "ambience/particle_suck1.wav";
			m_fRespawnTime = 10.0f;
			m_fDuration = 0.0f; // this effect is instantaneous and persistent
		}
		
		void Spawn()
		{
			PowerSpawn();
			
			SetTouch( TouchFunction(this.VitalityTouch) );
			SetThink( ThinkFunction(this.VitalityThink) );
			
			self.pev.rendermode = kRenderNormal;
			self.pev.renderfx = kRenderFxGlowShell;
			self.pev.renderamt = 32;
			self.pev.rendercolor = VitalityColor;
			
			m_vInitialOrigin = self.pev.origin; // I think at this point the Think function hasn't been called yet...
			
			return;
		}
		
		void Respawn() override
		{
			// make the entity interactable again
			// schedule think
			// play respawn sound
			
			self.pev.origin = m_vInitialOrigin;
			
			self.pev.effects ^= EF_NODRAW;
			self.pev.solid = SOLID_TRIGGER;
			SetTouch( TouchFunction(this.VitalityTouch) );
			SetThink( ThinkFunction(this.VitalityThink) );
			
			g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, m_sSoundFX_Spawn, 1.0, ATTN_NORM );
			
			self.pev.nextthink = g_Engine.time;
			
			return;
		}
		
		void VitalityTouch(CBaseEntity@ pOther)
		{
			CItemPower::PowerTouch(pOther);
			
			return;
		}
		
		void VitalityThink()
		{
			CItemPower::PowerThink();
			
			return;
		}
		
		void PowerUP( CBasePlayer@ pPlayer ) override
		{
			PowerUPGFXOn( VitalityColor, pPlayer );
			
			pPlayer.pev.max_health = 500;
			pPlayer.pev.health = 500;
			
			g_Scheduler.SetTimeout( @CItemPower_Vitality(), "PowerDOWN", 1.0f, @pPlayer );
			
			return;
		}
		
		void PowerDOWN( CBasePlayer@ pPlayer ) override
		{
			PowerUPGFXOff( pPlayer );
			
			pPlayer.ResetEffects();
			pPlayer.ApplyEffects();
			
			return;
		}
	}
	// #11
	class CItemPower_Ultimate : CItemPower // Invincible, Haste, DoubleDamage, AmmoRegeneration, Vitality, Amphibian, HighJump
	{
		void Spawn()
		{
		}
		
		void PowerUP( CBasePlayer@ pPlayer ) override
		{
		}
		
		void PowerDOWN( CBasePlayer@ pPlayer ) override
		{
		}
	}
	// #12
	class CItemPower_Gargantua : CItemPower // the idea is to make the player very big...not implemented
	{
		void Spawn()
		{
		}
		
		void PowerUP( CBasePlayer@ pPlayer ) override
		{
		}
		
		void PowerDOWN( CBasePlayer@ pPlayer ) override
		{
		}
	}
	// #13
	class CItemPower_Resurrection : CItemPower // revives the player automatically after death. this effect is going to be persistent until a player is revived.
	{
		private Vector ResurrectionColor = Vector( 152, 0, 163 ); // a dark pink-purple color
		private int UniquePlayerID;
		
		CItemPower_Resurrection()
		{
			m_sModel = "models/common/lambda.mdl";
			m_sSoundFX_Pickup = "ambience/particle_suck1.wav";
			m_fRespawnTime = 30.0f;
			m_fDuration = 0.0f; // this effect is instantaneous and lasts until player death
			m_bRespawn = false;
		}
		
		CItemPower_Resurrection( const CItemPower_Resurrection &in other )
		{
			UniquePlayerID = other.UniquePlayerID;
		}
		
		HookReturnCode Resurrect( CBasePlayer@ pPlayer, CBaseEntity@ pAttacker, int iGib )
		{
			if ( pPlayer is null ) return HOOK_CONTINUE;
			if ( pPlayer.IsAlive() ) return HOOK_CONTINUE;
			if ( !pPlayer.IsRevivable() ) return HOOK_CONTINUE;
			
			if ( g_EngineFuncs.GetPlayerUserId( pPlayer.edict() ) == UniquePlayerID)
			{
				pPlayer.Revive();
				
				return HOOK_HANDLED;
			}
			
			return HOOK_CONTINUE;
		}
		
		void Spawn()
		{
			PowerSpawn();
			
			SetTouch( TouchFunction(this.ResurrectionTouch) );
			SetThink( ThinkFunction(this.ResurrectionThink) );
			
			self.pev.rendermode = kRenderNormal;
			self.pev.renderfx = kRenderFxGlowShell;
			self.pev.renderamt = 32;
			self.pev.rendercolor = ResurrectionColor;
			
			m_vInitialOrigin = self.pev.origin; // I think at this point the Think function hasn't been called yet...
			
			
			return;
		}
		
		void Respawn() override
		{
			// make the entity interactable again
			// schedule think
			// play respawn sound
			
			self.pev.origin = m_vInitialOrigin;
			
			self.pev.effects ^= EF_NODRAW;
			self.pev.solid = SOLID_TRIGGER;
			SetTouch( TouchFunction(this.ResurrectionTouch) );
			SetThink( ThinkFunction(this.ResurrectionThink) );
			
			g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, m_sSoundFX_Spawn, 1.0, ATTN_NORM );
			
			UniquePlayerID = 0;
			
			self.pev.nextthink = g_Engine.time;
			
			return;
		}
		
		void ResurrectionTouch(CBaseEntity@ pOther)
		{
			if ( pOther is null) return;
			if ( !pOther.IsPlayer() ) return;
			if ( pOther.pev.health <= 0 ) return;
			
			UniquePlayerID = g_EngineFuncs.GetPlayerUserId( pOther.edict() );
			
			CItemPower::PowerTouch( pOther );
			
			return;
		}
		
		void ResurrectionThink()
		{
			CItemPower::PowerThink();
			
			return;
		}
		
		// make a hook that is called to revive the player when that player dies.
		void PowerUP(CBasePlayer@ pPlayer) override
		{
			PowerUPGFXOn( Vector(0,0,0), pPlayer );
			
			//g_Hooks.RegisterHook( Hooks::Player::PlayerKilled, @g_pResurrect = t_pfuncp(CItemPower_Resurrection(this).Resurrect) );
			
			return;
		}
		
		void PowerDOWN( CBasePlayer@ pPlayer ) override
		{
			PowerUPGFXOff( pPlayer );
			
			pPlayer.ResetEffects();
			pPlayer.ApplyEffects();
			
			return;
		}
	}
	
	void Register()
	{
		dictionary g_EntData;
		g_EntData[ 'CItemPower_Levitate' ] = 'item_power_levitate';
		g_EntData[ 'CItemPower_HighJump' ] = 'item_power_highjump';
		g_EntData[ 'CItemPower_Invincible' ] = 'item_power_invincible';
		g_EntData[ 'CItemPower_Ghost' ] = 'item_power_ghost';
		g_EntData[ 'CItemPower_Amphibian' ] = 'item_power_amphibian';
		g_EntData[ 'CItemPower_Invisibility' ] = 'item_power_invisibility';
		g_EntData[ 'CItemPower_Haste' ] = 'item_power_haste';
		g_EntData[ 'CItemPower_DoubleDamage' ] = 'item_power_doubledamage';
		g_EntData[ 'CItemPower_AmmoRegeneration' ] = 'item_power_ammoregen';
		g_EntData[ 'CItemPower_Vitality' ] = 'item_power_vitality';
		// g_EntData[ 'CItemPower_Resurrection' ] = 'item_power_resurrection'; // resurrection is unfinished

		array<string> strClasses = g_EntData.getKeys();

		for( uint ui = 0; ui < strClasses.length(); ui++ )
		{
			g_CustomEntityFuncs.RegisterCustomEntity( "SvenCoopPower::" + strClasses[ui], string( g_EntData[ strClasses[ui] ] ) );
			if( g_CustomEntityFuncs.IsCustomEntity( string( g_EntData[ strClasses[ui] ] ) )
				g_Game.PrecacheOther( string( g_EntData[ strClasses[ui] ] ) );
		}
	}

}

void CItemPowerManager_Respawn( SvenCoopPower::CItemPower@ pPower ) // this function is going to respawn the entity
{	
	if ( pPower is null ) return;
	
	pPower.Respawn(); // this doesn't work? hmm...UPDATE: after changing the reference type from EHandle to CItemPower@ this statement works as it should!
	
	return;
}

void CItemPowerManager_Delete( EHandle hEntity )
{
	if (  !hEntity.IsValid() ) return;
	
	g_EntityFuncs.Remove( hEntity.GetEntity() );
	
	return;
}

/*void CItemPowerManager_Revoke( CBasePlayer@ pPlayer ) // this function is going to remove the power-up effect from the player and return them to normal
{	
	if ( pPower is null ) return;
	if ( pPlayer is null ) return; // if this reference is null, probably the player disconnected
	
	CustomKeyvalues@ pKeyValues = pPlayer.GetCustomKeyvalues();
	
	pKeyValues.SetKeyvalue( "$s_HasPowerUp", "NO" );
	
	 // the player could be dead, but even so the player state needs to be returned to normal. do it now UPDATE: I think the player state is returned to normal after the player dies in the powerUP state.
	
	return;
}*/

/*HookReturnCode PlayerKeyInput( CBasePlayer@ pPlayer, In_Buttons Button, const bool bReleased )
{
	if ( pPlayer is null ) return HOOK_HANDLED;
	
	switch( Button )
    {
		case IN_JUMP:
		{
			if( bReleased )
			// Jump Key released
				break;
			else
			// Jump Key pressed
				pPlayer.pev.velocity.z = sqrt( 15 * 800 * 45.0f );
			break;
		}
		default:
			break;
	}
	
	return HOOK_HANDLED;
}*/

void CItemPowerManager_HighJump(CBasePlayer@ pPlayer)
{
	if ( pPlayer is null ) return;
	
	pPlayer.pev.velocity.z += sqrt( 20.0f * 800.0f * 45.0f );
	
	return;
}

void CItemPowerManager_AmmoRegen(CBasePlayer@ pPlayer) // OMG this actually works!, but it makes the game crash T_T UPDATE: not anymore, evidently 10 calls per second really is too fast and makes the game crash.
{
	if ( pPlayer is null ) return; // this probably shouldn't be null based on the way it is triggered, but the player could be disconnected before this
	if ( !pPlayer.IsAlive() ) return;
	if ( pPlayer.m_hActiveItem == false ) return;
	CBasePlayerWeapon@ pPlayerWeapon = cast<CBasePlayerWeapon@>(pPlayer.m_hActiveItem.GetEntity());
	if ( pPlayerWeapon is null ) return;
	if ( pPlayerWeapon.m_iClip == -1 ) // it's either a melee weapon or a non-clip weapon like the egon
	{
		// determine what ammo type, then add ammo
		int IndexAmmoPrimary = pPlayerWeapon.PrimaryAmmoIndex();
		if ( IndexAmmoPrimary == -1 ) return; // melee weapon
		else
		{
			int AmmoQuantity = pPlayer.AmmoInventory( IndexAmmoPrimary );
			int AmmoMax = pPlayer.GetMaxAmmo( IndexAmmoPrimary );
			if ( AmmoQuantity + 1 > pPlayer.GetMaxAmmo(IndexAmmoPrimary) ) return;
			else pPlayer.m_rgAmmo( IndexAmmoPrimary, AmmoMax );
			
			return;
		}
	}
	else
	{
		int ClipSizeMax = pPlayerWeapon.iMaxClip();
		if ( pPlayerWeapon.m_iClip + 1 > ClipSizeMax ) return;
		else
			pPlayerWeapon.m_iClip = ClipSizeMax;
	}
	
	return;
}

HookReturnCode CItemPowerManager_HasteSetBaseSpeed( CBasePlayer@ pPlayer )
{
	if ( pPlayer is null ) return HOOK_HANDLED; // this SHOULDN'T happen because the client JUST joined, but they could disconnect at this instant...
	
	//int sv_maxspeed = pPlayer.GetMaxSpeed();
	
	pPlayer.SetMaxSpeed( 270 ); // normal speed of 270
	
	return HOOK_HANDLED;
}

HookReturnCode SvenCoopPower_SetKeyValue( CBasePlayer@ pPlayer ) // this doesn't work
{
	CustomKeyvalues@ pKeyValues;
	
	@pKeyValues = pPlayer.GetCustomKeyvalues();
	
	pKeyValues.InitializeKeyvalueWithDefault( "$s_HasPowerUp" );
	
	if ( pKeyValues.HasKeyvalue( "$s_HasPowerUp" ) == false )
	{
		g_Game.AlertMessage( at_console, "ERROR: the game could not assign the key %s_HasPowerUp to a player!\n" );
		
		return HOOK_HANDLED;
	}
	
	pKeyValues.SetKeyvalue( "%s_HasPowerUp", "NO" );
	
	return HOOK_HANDLED;
}

// these functions are supposed to triggered from another entity, like a button, or a monster dying.
void CreateRandomPower( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue  ) // function signature of the Use function
{
	int rando = Math.RandomLong( 1, 10 );
	
	switch ( rando )
	{
		case 1:
			g_EntityFuncs.Create( "item_power_levitate", pCaller.pev.origin + Vector(0,0,32), pCaller.pev.angles, false );
			break;
		case 2:
			g_EntityFuncs.Create( "item_power_highjump", pCaller.pev.origin + Vector(0,0,32), pCaller.pev.angles, false );
			break;
		case 3:
			g_EntityFuncs.Create( "item_power_invincible", pCaller.pev.origin + Vector(0,0,32), pCaller.pev.angles, false );
			break;
		case 4:
			g_EntityFuncs.Create( "item_power_ghost", pCaller.pev.origin + Vector(0,0,32), pCaller.pev.angles, false );
			break;
		case 5:
			g_EntityFuncs.Create( "item_power_amphibian", pCaller.pev.origin + Vector(0,0,32), pCaller.pev.angles, false );
			break;
		case 6:
			g_EntityFuncs.Create( "item_power_invisibility", pCaller.pev.origin + Vector(0,0,32), pCaller.pev.angles, false );
			break;
		case 7:
			g_EntityFuncs.Create( "item_power_haste", pCaller.pev.origin + Vector(0,0,32), pCaller.pev.angles, false );
			break;
		case 8:
			g_EntityFuncs.Create( "item_power_doubledamage", pCaller.pev.origin + Vector(0,0,32), pCaller.pev.angles, false );
			break;
		case 9:
			g_EntityFuncs.Create( "item_power_ammoregen", pCaller.pev.origin + Vector(0,0,32), pCaller.pev.angles, false );
			break;
		case 10:
			g_EntityFuncs.Create( "item_power_vitality", pCaller.pev.origin + Vector(0,0,32), pCaller.pev.angles, false );
			break;
		default:
			break;
	}
	
	return;
}

void CreateWeightedRandomCombatPower( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue ) // function signature of the Use function
{
	int rando = Math.RandomLong( 1, 100 );
	
	if ( rando > 0 && rando <= 80 ) return; // you get nothing!
	if ( rando > 80 && rando <= 85 ) g_EntityFuncs.Create( "item_power_haste", pCaller.pev.origin + Vector(0,0,32), pCaller.pev.angles, false );
	if ( rando > 85 && rando <= 90 ) g_EntityFuncs.Create( "item_power_doubledamage", pCaller.pev.origin + Vector(0,0,32), pCaller.pev.angles, false );
	if ( rando > 90 && rando <= 95 ) g_EntityFuncs.Create( "item_power_ammoregen", pCaller.pev.origin + Vector(0,0,32), pCaller.pev.angles, false );
	if ( rando > 95 && rando <= 100 ) g_EntityFuncs.Create( "item_power_invincible", pCaller.pev.origin + Vector(0,0,32), pCaller.pev.angles, false );
	
	return;
}

// resurrect is going to be tricky to implement, i need to target a specific player in the game to revive, and there is no straight way to do this.
/*HookReturnCode CItemPowerManager_Resurrect( CBasePlayer@ pPlayer, CBaseEntity@ pAttacker, int iGib ) // this function revives a player after death
{
	if ( pPlayer is null ) return;
	if ( pPlayer.IsAlive() ) return;
	if ( !pPlayer.IsRevivable() ) return;
	
	pPlayer.Revive();
	
	return HOOK_HANDLED;
}*/
