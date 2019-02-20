include "globals.mzn";

%----Parameters----
int: weeks; % #weeks for the planning
int: types; % #types of spacecraft
% Order[t,w] = #spacecrafts of type t to assemble by end of week w:
array[1..types,1..weeks] of 0..1: Order;
int: storageCost; % cost of storing one spacecraft during one week
% SetupCost[t1,t2] = cost of adapting factory from type t1 to t2:
array[1..types,1..types] of int: SetupCost;

%----Pre-computed parameters----
int: numOrders = sum(Order); % total #spacecrafts to assemble
int: sumSetupCost = sum(SetupCost); % total #setupCost
int: maxCost = weeks*types*numOrders*storageCost*sumSetupCost*100; % upper bound cost
set of int: ORDERS = 1..numOrders; % index range of orders of spacecraft
set of int: TYPES = 1..types; % index range of types of spacecraft
set of int: WEEKS = 1..weeks; % index range of weeks

%----Decision variables----
% all adaptation cost of the factory when switching between spacecraft types
var 0..maxCost: allSetupCost;
% all storage cost of the spacecrafts that are completed before their due date
var 0..maxCost: allStorageCost; 
% total cost
var 0..maxCost: totalCost;
% weekPlan[ord] = the week to assemble order ord
array[ORDERS] of var WEEKS: weekPlan;
% craftType[ord] = type of spacecraft of order ord
array[ORDERS] of var TYPES: craftType;

%----Constraints----
% At most one spacecraft can be assembled per week
constraint alldifferent(weekPlan) :: domain; % consistency

% The due week of order o of spacecraft is specified, so weekPlan is sorted increasingly
constraint increasing(weekPlan) :: domain;

% #produced-order of spacecraft of type t is no less than #original-order of spacecrafts of type t
constraint forall(t in TYPES, w in WEEKS)(
    % #produced-order of spacecraft of type t
    sum([bool2int(weekPlan[o] <= w /\ craftType[o] = t) | o in ORDERS])
    >= 
    % #original-order of spacecraft of type t
    sum([Order[t,i] | i in 1..w])
);

% the sum of storage cost for every week based on multiplying storageCost by the difference between produced-order of spacecrafts and original-order.
constraint allStorageCost = 
    (sum(w in WEEKS)(
        % #produced-order of spacecrafts
        sum([bool2int(weekPlan[o] <= w) | o in ORDERS])
        -
        % #original-order of spacecrafts
        sum([Order[t,w] | w in 1..w, t in TYPES])
        )
    ) * storageCost;
    
% the sum of all adaptation cost of the factory when switching between spacecraft types
constraint allSetupCost = sum([SetupCost[craftType[o], craftType[o+1]] | o in 1..numOrders-1]);

constraint totalCost = allSetupCost + allStorageCost;

%----Objective----
solve 
  :: seq_search([int_search(weekPlan, occurrence, indomain_min, complete),
                 int_search(craftType, occurrence, indomain_min, complete)]) 
  minimize totalCost;

%----Output----
output ["Craft type: " ++ show(craftType) ++ "\n" ++
        "Week plan: " ++ show(weekPlan) ++ "\n" ++
        "Total cost: " ++ show(totalCost)];
