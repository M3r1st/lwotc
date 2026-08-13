//---------------------------------------------------------------------------------------
//  FILE:    X2Effect_MeristLayeredArmorV2.uc
//  AUTHOR:  Merist
//  PURPOSE: Reduce all incoming damage for the rest of the turn
//           whenever a unit takes damage above a percent of their
//           max HP in a single turn
//---------------------------------------------------------------------------------------
class X2Effect_MeristLayeredArmorV2 extends X2Effect_MeristLayeredArmor;

// Damage reduction IN PERCENTS above the cap
var float FinalPrcDamageModifier;
var array<float> FinalPrcDamageModifierDifficulty;
var float MaxFinalPrcDamageModifier;

function float GetFinalDamageModifierPercent(XComGameState_Unit Unit)
{
    local float DamageModifier;

    if (bUseDifficulySettings)
        DamageModifier = FinalPrcDamageModifierDifficulty[`TACTICALDIFFICULTYSETTING];
    else
        DamageModifier = FinalPrcDamageModifier;

    DamageModifier = FMin(DamageModifier, MaxFinalPrcDamageModifier);
    `LOG("DamageModifier = " $ DamageModifier, default.bLog, default.Class.Name);
    return DamageModifier;
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
    local float MaxHealth, DamageTaken, MaxDamage, DamageOverflow, DamageReduction;
    local UnitValue UValue;
    // Variables for preview
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
                TargetUnit.GetUnitValue('DamageThisTurn', UValue);
                DamageTaken = UValue.fValue;
                `LOG("DamageTaken = " $ DamageTaken, default.bLog, default.Class.Name);
                MaxDamage = FMax(MaxHealth * GetPercentDamageCap(TargetUnit) / 100 - DamageTaken, 0);
                `LOG("MaxDamage = " $ MaxDamage, default.bLog, default.Class.Name);
                if (bCheckGameState)
                {
                    if (NewGameState != none)
                    {
                        NewTargetState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(TargetUnit.ObjectID));
                        if (NewTargetState != none)
                        {
                            `LOG("NewTargetState != none", default.bLog, default.Class.Name);
                            NewTargetState.GetUnitValue('DamageThisTurn', UValue);
                            DamageTaken = UValue.fValue;
                            MaxDamage = FMax(MaxHealth * GetPercentDamageCap(TargetUnit) / 100 - DamageTaken, 0);
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
                            DamageReduction = FClamp(DamageOverflow * GetFinalDamageModifierPercent(TargetUnit) / 100, 0, WeaponDamage);
                            `LOG("DamageReduction = " $ DamageReduction, default.bLog, default.Class.Name);
                            `LOG("<<<", default.bLog, default.Class.Name);
                            return -1 * DamageReduction;
                        }
                    }
                }
                DamageOverflow = FClamp(WeaponDamage - MaxDamage, 0, WeaponDamage);
                `LOG("DamageOverflow = " $ DamageOverflow, default.bLog, default.Class.Name);
                DamageReduction = FClamp(DamageOverflow * GetFinalDamageModifierPercent(TargetUnit) / 100, 0, WeaponDamage);
                `LOG("DamageReduction = " $ DamageReduction, default.bLog, default.Class.Name);
                `LOG("<<<", default.bLog, default.Class.Name);
                return -1 * DamageReduction;
            }
        }
    }

    return 0;
}

defaultproperties
{
    EffectName = "EnhancedLayeredArmor"
    MaxFinalPrcDamageModifier = 95.0
}