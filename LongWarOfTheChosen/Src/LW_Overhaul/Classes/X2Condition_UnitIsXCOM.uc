class X2Condition_UnitIsXCOM extends X2Condition;

var bool bCheckCanEverBeValid;

event name CallMeetsCondition(XComGameState_BaseObject kTarget) 
{
    local XComGameState_Unit UnitState;
    
    UnitState = XComGameState_Unit(kTarget);
    
    if (UnitState == none)
        return 'AA_NotAUnit';
        
    if (UnitState.GetPreviousTeam() == eTeam_XCom)
        return 'AA_Success'; 

    return 'AA_AbilityUnavailable';
}

function bool CanEverBeValid(XComGameState_Unit SourceUnit, bool bStrategyCheck)
{
    if (!bCheckCanEverBeValid)
        return true;

    if (bStrategyCheck)
        return true;

    if (SourceUnit.GetPreviousTeam() == eTeam_XCom)
        return true;

    return false;
}

defaultproperties
{
    bCheckCanEverBeValid = false
}