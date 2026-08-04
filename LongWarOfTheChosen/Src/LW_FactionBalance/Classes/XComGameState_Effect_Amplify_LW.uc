//---------------------------------------------------------------------------------------
//  FILE:    XComGameState_Effect_Amplify_LW.uc
//  AUTHOR:  Grobobobo
//  PURPOSE: Makes the Amplify effect work for a flat number of attacks
//---------------------------------------------------------------------------------------
class XComGameState_Effect_Amplify_LW extends XComGameState_Effect_Amplify;

function PostCreateInit(EffectAppliedData InApplyEffectParameters, GameRuleStateChange WatchRule, XComGameState NewGameState)
{
    local X2Effect_Amplify_LW AmplifyEffect;

    super(XComGameState_Effect).PostCreateInit(InApplyEffectParameters, WatchRule, NewGameState);

    AmplifyEffect = X2Effect_Amplify_LW(GetX2Effect());

    if (AmplifyEffect != none)
    {
        ShotsRemaining = AmplifyEffect.NumShots;
    }
    else
    {
        ShotsRemaining = class'X2Ability_TemplarAbilitySet_LW'.default.AMPLIFY_SHOTS;
    }
}
