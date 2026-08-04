//---------------------------------------------------------------------------------------
//  FILE:    X2Effect_Amplify_LW.uc
//  AUTHOR:  Grobobobo
//  PURPOSE: Updates the Amplify effect so that it's removed immediately after a single attack.
//---------------------------------------------------------------------------------------
class X2Effect_Amplify_LW extends X2Effect_Amplify;

var int NumShots;
var bool bApplyToDOT;

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
    local XComGameState_Effect_Amplify_LW AmplifyState;
    local float DamageMod;
    local bool bIsDOT;

    if (class'XComGameStateContext_Ability'.static.IsHitResultHit(ApplyEffectParameters.AbilityResultContext.HitResult))
    {
        if (WeaponDamage > 0)
        {
            bIsDOT = ApplyEffectParameters.EffectRef.ApplyOnTickIndex != INDEX_NONE;
            if (bIsDOT && !bApplyToDOT)
            {
                return 0;
            }

            DamageMod = BonusDamageMult * WeaponDamage;
            if (DamageMod < MinBonusDamage)
            {
                DamageMod = MinBonusDamage;
            }

            if (NumShots > 0 && !bIsDOT)
            {
                // if NewGameState was passed in, we are really applying damage, so update our counter or remove the effect if it's worn off
                if (NewGameState != none)
                {
                    AmplifyState = XComGameState_Effect_Amplify_LW(EffectState);
                    if (AmplifyState != none)
                    {
                        if (AmplifyState.ShotsRemaining <= 1 && !AmplifyState.bRemoved)
                        {
                            AmplifyState.RemoveEffect(NewGameState, NewGameState);
                        }
                        else
                        {
                            AmplifyState = XComGameState_Effect_Amplify_LW(NewGameState.ModifyStateObject(AmplifyState.Class, AmplifyState.ObjectID));
                            AmplifyState.ShotsRemaining -= 1;
                        }
                        NewGameState.GetContext().PostBuildVisualizationFn.AddItem(AmplifyDecrement_PostBuildVisualization);
                    }
                }
            }
        }
    }

    return DamageMod;
}

function int GetDefendingDamageModifier(XComGameState_Effect EffectState, XComGameState_Unit Attacker, Damageable TargetDamageable, XComGameState_Ability AbilityState, const out EffectAppliedData AppliedData, const int CurrentDamage, X2Effect_ApplyWeaponDamage WeaponDamageEffect, optional XComGameState NewGameState)
{
    return 0;
}

defaultproperties
{
    GameStateEffectClass = class'XComGameState_Effect_Amplify_LW'
}
