class X2Effect_ClearUnitValuesOnTick extends X2Effect_Persistent;

var array<name> ValuesToClear;

simulated function bool OnEffectTicked(const out EffectAppliedData ApplyEffectParameters, XComGameState_Effect kNewEffectState, XComGameState NewGameState, bool FirstApplication, XComGameState_Player Player)
{
    local XComGameState_Unit TargetUnit;
    local bool bContinueTicking;
    local name ValueName;

    bContinueTicking = super.OnEffectTicked(ApplyEffectParameters, kNewEffectState, NewGameState, FirstApplication, Player);

    if (ValuesToClear.Length > 0)
    {
        TargetUnit = XComGameState_Unit(NewGameState.GetGameStateForObjectID(ApplyEffectParameters.TargetStateObjectRef.ObjectID));
        if (TargetUnit == none)
        {
            TargetUnit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', ApplyEffectParameters.TargetStateObjectRef.ObjectID));
        }
        if (TargetUnit != none)
        {
            foreach ValuesToClear(ValueName)
            {
                TargetUnit.ClearUnitValue(ValueName);
            }
        }
    }

    return bContinueTicking;
}