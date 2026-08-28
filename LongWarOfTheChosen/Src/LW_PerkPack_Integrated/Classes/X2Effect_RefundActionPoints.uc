//---------------------------------------------------------------------------------------
//  FILE:    X2Effect_RefundActionPoints.uc
//  AUTHOR:  Merist
//  PURPOSE: Adding or refunding action points when an ability is activatied
//---------------------------------------------------------------------------------------
class X2Effect_RefundActionPoints extends X2Effect_Persistent config(LW_SoldierSkills);

var array<name> AllowedAbilities;

// If `true`, PostAbilityCostPaid will be used to return the action point array to the previous state
// If `false`, OnAbilityActivated will be used to add an action point
var bool bRefundAll;
// The of the action point to add if `bRefundAll = false`
var name ActionPointType;

// Require the source weapon of the effect and the ability to match
var bool bMatchSourceWeapon;

// Name of the value to count activations
var name CountValueName;
// Max number of activations per turn
var int ActivationsPerTurn;

// Add effect flyover visualization
var bool bShowFlyover;
// EventID to use for a flyover if `bRefundAll = true`
var name FlyoverEventName;

// Allow using Cost-Based Ability Colors' tuple to adjust the color
// Cannot rely on ability context
var bool bAllowCBACOverride;
var string strCBACOverrideColor;
var config array<name> CBAC_AllowedTypes;

function RegisterForEvents(XComGameState_Effect EffectGameState)
{
    local X2EventManager EventMgr;
    local XComGameState_Unit TargetUnit;
    local Object EffectObj;

    EventMgr = `XEVENTMGR;

    EffectObj = EffectGameState;
    TargetUnit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(EffectGameState.ApplyEffectParameters.TargetStateObjectRef.ObjectID));

    if (bRefundAll && bShowFlyover && FlyoverEventName != '')
    {
        EventMgr.RegisterForEvent(EffectObj, FlyoverEventName, EffectGameState.TriggerAbilityFlyover, ELD_OnStateSubmitted,, TargetUnit);
    }

    if (!bRefundAll)
    {
        EventMgr.RegisterForEvent(EffectObj, 'AbilityActivated', OnAbilityActivated, ELD_OnStateSubmitted,, TargetUnit,, EffectObj);
    }

    /// ```event
    /// EventID: OverrideAbilityIconColorCBAC,
    /// EventData: [
    ///     in XComGameState AbilityState,
    ///     out bool bOverride,
    ///     inout string EventOverrideColor,
    ///     inout int PointCost,
    ///     inout int TurnEnding
    /// ],
    /// EventSource: XComGameState_Unit (UnitState)
    /// NewGameState: none
    /// ```
    if (bAllowCBACOverride)
    {
        EventMgr.RegisterForEvent(EffectObj, 'OverrideAbilityIconColorCBAC', OnOverrideAbilityIconColor, ELD_Immediate,, TargetUnit,, EffectObj);
    }
}

static function EventListenerReturn OnOverrideAbilityIconColor(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
    local XComLWTuple                   Tuple;
    local bool                          bOverride;
    local XComGameState_Unit            UnitState;
    local XComGameState_Ability         AbilityState;
    local XComGameState_Effect          EffectState;
    local X2Effect_RefundActionPoints   Effect;
    local string                        strOverrideColor;
    local int                           PointCost;
    local bool                          bIsTurnEnding;

    Tuple = XComLWTuple(EventData);

    `assert(Tuple != none);
    `assert(Tuple.Id == 'OverrideAbilityIconColorCBAC');

    bOverride = Tuple.Data[1].b;
    strOverrideColor = Tuple.Data[2].s;
    PointCost = Tuple.Data[3].i;
    bIsTurnEnding = bool(Tuple.Data[4].i);

    if (PointCost > 0)
    {
        UnitState = XComGameState_Unit(EventSource);
        AbilityState = XComGameState_Ability(Tuple.Data[0].o);
        EffectState = XComGameState_Effect(CallbackData);
        if (UnitState != none && AbilityState != none && EffectState != none)
        {
            Effect = X2Effect_RefundActionPoints(EffectState.GetX2Effect());
            if (Effect != none)
            {
                if (Effect.IsEffectCurrentlyRelevant(EffectState, UnitState))
                {
                    if (Effect.IsAbilityRelevant(AbilityState, UnitState, EffectState))
                    {
                        if (Effect.bRefundAll)
                        {
                            bOverride = true;
                            PointCost = 0;
                            bIsTurnEnding = false;
                        }
                        else
                        {
                            if (bIsTurnEnding)
                            {
                                if (default.CBAC_AllowedTypes.Find(Effect.ActionPointType) != INDEX_NONE)
                                {
                                    bOverride = true;
                                    PointCost = Max(0, UnitState.ActionPoints.Length - 1);
                                    bIsTurnEnding = false;
                                }
                            }
                            else
                            {
                                bOverride = true;
                                PointCost = Max(0, PointCost - 1);
                            }
                        }

                        if (bOverride)
                        {
                            if (strOverrideColor == "")
                            {
                                strOverrideColor = Effect.strCBACOverrideColor;
                            }
                            Tuple.Data[1].b = bOverride;
                            Tuple.Data[2].s = strOverrideColor;
                            Tuple.Data[3].i = PointCost;
                            Tuple.Data[4].i = int(bIsTurnEnding);
                        }
                    }
                }
            }
        }
    }

    return ELR_NoInterrupt;
}

static function EventListenerReturn OnAbilityActivated(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
    local XComGameStateContext_Ability  AbilityContext;
    local XComGameState_Unit            SourceUnit;
    local XComGameState_Ability         AbilityState;
    local XComGameState_Effect          EffectState;
    local X2Effect_RefundActionPoints   Effect;
    local XComGameState                 NewGameState;
    local UnitValue                     CountUnitValue;

    AbilityContext = XComGameStateContext_Ability(GameState.GetContext());

    if (AbilityContext != none && AbilityContext.InterruptionStatus != eInterruptionStatus_Interrupt)
    {
        SourceUnit = XComGameState_Unit(EventSource);
        AbilityState = XComGameState_Ability(EventData);
        EffectState = XComGameState_Effect(CallbackData);

        if (SourceUnit != none && AbilityState != none && EffectState != none)
        {
            Effect = X2Effect_RefundActionPoints(EffectState.GetX2Effect());

            if (Effect != none)
            {
                if (Effect.IsEffectCurrentlyRelevant(EffectState, SourceUnit))
                {
                    if (Effect.IsAbilityRelevant(AbilityState, SourceUnit, EffectState))
                    {
                        if (!WasAbilityFree(AbilityState, SourceUnit, GameState.HistoryIndex - 1))
                        {
                            NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState(string(GetFuncName()));
                            SourceUnit = XComGameState_Unit(NewGameState.ModifyStateObject(SourceUnit.Class, SourceUnit.ObjectID));

                            if (Effect.CountValueName != '')
                            {
                                SourceUnit.GetUnitValue(Effect.CountValueName, CountUnitValue);
                                SourceUnit.SetUnitFloatValue(Effect.CountValueName, CountUnitValue.fValue + 1, eCleanup_BeginTurn);
                            }

                            if (Effect.bShowFlyover)
                            {
                                NewGameState.ModifyStateObject(class'XComGameState_Ability', EffectState.ApplyEffectParameters.AbilityStateObjectRef.ObjectID);
                                XComGameStateContext_ChangeContainer(NewGameState.GetContext()).BuildVisualizationFn = EffectState.TriggerAbilityFlyoverVisualizationFn;
                            }

                            SourceUnit.ActionPoints.AddItem(Effect.GetActionPointType());

                            `TACTICALRULES.SubmitGameState(NewGameState);
                        }
                    }
                }
            }
        }
    }

    return ELR_NoInterrupt;
}

function bool PostAbilityCostPaid(
    XComGameState_Effect EffectState,
    XComGameStateContext_Ability AbilityContext,
    XComGameState_Ability kAbility,
    XComGameState_Unit SourceUnit,
    XComGameState_Item AffectWeapon,
    XComGameState NewGameState,
    const array<name> PreCostActionPoints,
    const array<name> PreCostReservePoints)
{
    local XComGameState_Ability EffectAbilityState;
    local UnitValue             CountUnitValue;

    if (bRefundAll)
    {
        if (IsEffectCurrentlyRelevant(EffectState, SourceUnit))
        {
            if (IsAbilityRelevant(kAbility, SourceUnit, EffectState))
            {
                if (!WasAbilityFree(kAbility, SourceUnit))
                {
                    if (CountValueName != '')
                    {
                        SourceUnit.GetUnitValue(CountValueName, CountUnitValue);
                        SourceUnit.SetUnitFloatValue(CountValueName, CountUnitValue.fValue + 1, eCleanup_BeginTurn);
                    }

                    if (bShowFlyover && FlyoverEventName != '')
                    {
                        EffectAbilityState = XComGameState_Ability(`XCOMHISTORY.GetGameStateForObjectID(EffectState.ApplyEffectParameters.AbilityStateObjectRef.ObjectID));
                        `XEVENTMGR.TriggerEvent(FlyoverEventName, EffectAbilityState, SourceUnit, NewGameState);
                    }

                    SourceUnit.ActionPoints = PreCostActionPoints;
                    return true;
                }
            }
        }
    }

    return false;
}

function bool IsAbilityRelevant(XComGameState_Ability AbilityState, XComGameState_Unit SourceUnit, XComGameState_Effect EffectState)
{
    if (AllowedAbilities.Length > 0 && AllowedAbilities.Find(AbilityState.GetMyTemplateName()) == INDEX_NONE)
    {
        return false;
    }

    if (bMatchSourceWeapon)
    {
        if (AbilityState.SourceWeapon.ObjectID > 0)
        {
            if (AbilityState.SourceWeapon != EffectState.ApplyEffectParameters.ItemStateObjectRef)
            {
                return false;
            }
        }
        else
        {
            return false;
        }
    }

    return true;
}

function bool IsEffectCurrentlyRelevant(XComGameState_Effect EffectGameState, XComGameState_Unit TargetUnit)
{
    local UnitValue CountUnitValue;

    if (class'Helpers_LW'.static.IsUnitInterruptingEnemyTurn(TargetUnit))
    {
        return false;
    }

    if (CountValueName != '')
    {
        TargetUnit.GetUnitValue(CountValueName, CountUnitValue);
        if (ActivationsPerTurn > 0 && CountUnitValue.fValue >= ActivationsPerTurn)
            return false;
    }
    
    return true;
}


function name GetActionPointType()
{
    if (ActionPointType != '')
    {
        return ActionPointType;
    }
    else
    {
        return class'X2CharacterTemplateManager'.default.StandardActionPoint;
    }
}

static function bool WasAbilityFree(XComGameState_Ability AbilityState, XComGameState_Unit AbilityOwner, optional int HistoryIndex = -1)
{
    local XComGameStateHistory      History;
    local XComGameState_Ability     OldAbilityState;
    local XComGameState_Unit        OldAbilityOwner;
    local X2AbilityTemplate         Template;
    local X2AbilityCost             Cost;
    local X2AbilityCost_ActionPoints ActionPointCost;

    History = `XCOMHISTORY;

    Template = AbilityState.GetMyTemplate();

    if (HistoryIndex != -1)
    {
        OldAbilityState = XComGameState_Ability(History.GetGameStateForObjectID(AbilityState.ObjectID,, HistoryIndex));
        OldAbilityOwner = XComGameState_Unit(History.GetGameStateForObjectID(AbilityOwner.ObjectID,, HistoryIndex));
    }
    else
    {
        OldAbilityState = XComGameState_Ability(History.GetGameStateForObjectID(AbilityState.ObjectID));
        OldAbilityOwner = XComGameState_Unit(History.GetGameStateForObjectID(AbilityOwner.ObjectID));
    }

    foreach Template.AbilityCosts(Cost)
    {
        ActionPointCost = X2AbilityCost_ActionPoints(Cost);
        if (ActionPointCost != none)
        {
            if (!ActionPointCost.bFreeCost && ActionPointCost.GetPointCost(OldAbilityState, OldAbilityOwner) > 0)
            {
                return false;
            }
        }
    }

    return true;
}

defaultproperties
{
    EffectName = RefundActionPoints_LW
    DuplicateResponse = eDupe_Ignore
    bRefundAll = true

    bAllowCBACOverride = false
}