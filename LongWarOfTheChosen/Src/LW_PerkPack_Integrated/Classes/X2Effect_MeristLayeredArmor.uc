//---------------------------------------------------------------------------------------
//  FILE:    X2Effect_MeristLayeredArmor.uc
//  AUTHOR:  Merist
//  PURPOSE: Clamp incoming damage to a percent of max HP 
//---------------------------------------------------------------------------------------
class X2Effect_MeristLayeredArmor extends X2Effect_Persistent config(LW_SoldierSkills);

struct AdditionalDamageCapInfo
{
    var name RequiredAbility;
    var float Modifier;

    var bool bModUseDifficulySettings;
    var array<float> ModifierDifficulty;
};

var config bool bLog;

// Damage cap from max HP per attack IN PERCENTS:
var float PrcDamageCap;
var bool bUseDifficulySettings;
var array<float> PrcDamageCapDifficulty;
var float MinPrcDamageCap;
var array<AdditionalDamageCapInfo> AdditionalPrcDamageCap;

// If true, all damage done in this game state frame will be treated as a single attack 
var bool bCheckGameState;

function AddAdditionalDamageCapInfo(name RequiredAbility, optional float Modifier, optional bool bModUseDifficulySettings, optional array<float> ModifierDifficulty)
{
    local AdditionalDamageCapInfo AdditionalInfo;
    AdditionalInfo.RequiredAbility = RequiredAbility;
    AdditionalInfo.Modifier = Modifier;
    AdditionalInfo.bModUseDifficulySettings = bModUseDifficulySettings;
    AdditionalInfo.ModifierDifficulty = ModifierDifficulty;
    AdditionalPrcDamageCap.AddItem(AdditionalInfo);
}

function float GetPercentDamageCap(XComGameState_Unit Unit)
{
    local AdditionalDamageCapInfo AdditionalInfo;
    local float DamageCap;

    if (bUseDifficulySettings)
        DamageCap = PrcDamageCapDifficulty[`TACTICALDIFFICULTYSETTING];
    else
        DamageCap = PrcDamageCap;
    
    foreach AdditionalPrcDamageCap(AdditionalInfo)
    {
        if (Unit.HasSoldierAbility(AdditionalInfo.RequiredAbility, true))
        {
            if (AdditionalInfo.bModUseDifficulySettings)
                DamageCap += AdditionalInfo.ModifierDifficulty[`TACTICALDIFFICULTYSETTING];
            else
                DamageCap += AdditionalInfo.Modifier;
        }
    }

    DamageCap = FMax(DamageCap, MinPrcDamageCap);
    `LOG("DamageCap = " $ DamageCap, default.bLog, default.Class.Name);
    return DamageCap;
}

function float GetPostDefaultDefendingDamageModifier_CH(
    XComGameState_Effect EffectState,
    XComGameState_Unit SourceUnit,
    XComGameState_Unit TargetUnit,
    XComGameState_Ability AbilityState,
    const out EffectAppliedData ApplyEffectParameters,
    float WeaponDamage,
    X2Effect_ApplyWeaponDamage WeaponDamageEffect,
    XComGameState NewGameState)
{
    local XComGameState_Unit NewTargetState;
    local UnitValue UValue;
    local float MaxHealth, MaxDamage, DamageOverflow;
    // Variables for damage preview
    local int NumHits;
    local float FullDamage, FullDamageOverflow;

    if (class'XComGameStateContext_Ability'.static.IsHitResultHit(ApplyEffectParameters.AbilityResultContext.HitResult))
    {
        if (WeaponDamage > 0)
        {
            if (TargetUnit != none)
            {
                `LOG(">>>", default.bLog, default.Class.Name);
                `LOG("WeaponDamage = " $ WeaponDamage, default.bLog, default.Class.Name);
                MaxHealth = TargetUnit.GetMaxStat(eStat_HP) + 0.01f;
                `LOG("MaxHealth = " $ MaxHealth, default.bLog, default.Class.Name);
                MaxDamage = MaxHealth * GetPercentDamageCap(TargetUnit) / 100;
                MaxDamage = FMax(MaxDamage, 0);
                `LOG("MaxDamage = " $ MaxDamage, default.bLog, default.Class.Name);
                
                if (bCheckGameState)
                {
                    if (NewGameState != none)
                    {
                        NewTargetState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(TargetUnit.ObjectID));
                        if (NewTargetState != none)
                        {
                            `LOG("NewTargetState != none", default.bLog, default.Class.Name);
                            // Reduce max amount of damage by the amount of damage taken this frame
                            TargetUnit.GetUnitValue('DamageThisTurn', UValue);
                            MaxDamage += UValue.fValue;
                            NewTargetState.GetUnitValue('DamageThisTurn', UValue);
                            MaxDamage -= UValue.fValue;
                            MaxDamage = FMax(MaxDamage, 0);
                            `LOG("MaxDamage = " $ MaxDamage, default.bLog, default.Class.Name);
                        }
                    }
                    else // This is damage preview
                    {
                        NumHits = GetNumHitsForAbility(AbilityState);
                        `LOG("NumHits = " $ NumHits, default.bLog, default.Class.Name);
                        if (NumHits > 1)
                        {
                            FullDamage = WeaponDamage * NumHits;
                            `LOG("FullDamage = " $ FullDamage, default.bLog, default.Class.Name);
                            FullDamageOverflow = FClamp(FullDamage - MaxDamage, 0, FullDamage);
                            `LOG("FullDamageOverflow = " $ FullDamageOverflow, default.bLog, default.Class.Name);
                            DamageOverflow = FClamp(FullDamageOverflow / NumHits, 0, WeaponDamage);
                            `LOG("DamageOverflow = " $ DamageOverflow, default.bLog, default.Class.Name);
                            `LOG("<<<", default.bLog, default.Class.Name);
                            return -1 * DamageOverflow;
                        }
                    }
                }
                DamageOverflow = FClamp(WeaponDamage - MaxDamage, 0, WeaponDamage);
                `LOG("DamageOverflow = " $ DamageOverflow, default.bLog, default.Class.Name);
                `LOG("<<<", default.bLog, default.Class.Name);
                return -1 * DamageOverflow;
            }
        }
    }

    return 0;
}

static function int GetNumHitsForAbility(XComGameState_Ability AbilityState)
{
    local X2AbilityTemplate AbilityTemplate;
    local X2AbilityMultiTarget_BurstFire BurstFire;
    local XComGameState_Unit AbilityOwner;

    AbilityTemplate = AbilityState.GetMyTemplate();
    BurstFire = X2AbilityMultiTarget_BurstFire(AbilityTemplate.AbilityMultiTargetStyle);
    if (BurstFire != none)
    {
        return 1 + BurstFire.NumExtraShots;
    }
    else if (X2AbilityMultiTarget_RadiusTimesFocus(AbilityTemplate.AbilityMultiTargetStyle) != none)
    {
        AbilityOwner = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(AbilityState.OwnerStateObject.ObjectID));
        return AbilityOwner.GetTemplarFocusLevel();
    }
    return 1;
}

defaultproperties
{
    EffectName = "LayeredArmor"
    DuplicateResponse = eDupe_Ignore
    bCheckGameState = true
    bDisplayInSpecialDamageMessageUI = true
    MinPrcDamageCap = 5.0
}