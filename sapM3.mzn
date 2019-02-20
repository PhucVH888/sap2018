include "globals.mzn";

%----Parameters----
int: weeks; % #weeks for the planning
int: types; % #types of spacecraft
% Order[t,w] = #spacecrafts of type t to assemble by end of week w:
array[1..types,1..weeks] of 0..1: Order;
int: storageCost; % cost of storing one spacecraft during one week
% SetupCost[t1,t2] = cost of adapting factory from type t1 to t2:
array[1..types,1..types] of int: SetupCost;

%----Pre-computed parameters ----
set of int: TYPES = 1..types; % index range of types of spacecraft
set of int: WEEKS = 1..weeks; % index range of weeks
int: numOrders = sum(Order); % Viewpoint 2: total #spacecrafts to assemble
set of int: ORDERS = 1..numOrders; % Viewpoint 2: index range of order
int: sumSetupCost = sum(SetupCost); % total #setupCost
int: maxCost = weeks*types*numOrders*storageCost*sumSetupCost*100; % upper bound cost

%----Decision variables----
% all adaptation cost of the factory when switching between spacecraft types
var 0..maxCost: allSetupCost;
% all storage cost of the spacecrafts that are completed before their due date
var 0..maxCost: allStorageCost; 
% total cost
var 0..maxCost: totalCost;
% Viewpoint 1: typePlan[w] = spacecrafts of that type to assemble at week w
array[WEEKS] of var TYPES: typePlan;
% Viewpoint 1: typeStatus[w] = 0 or 1 spacecraft is done at week w
array[WEEKS] of var 0..1: typeStatus;
% Viewpoint 2: weekPlan[ord] = the week to assemble order ord
array[ORDERS] of var WEEKS: weekPlan;
% Viewpoint 2: craftType[ord] = type of spacecraft of order ord
array[ORDERS] of var TYPES: craftType;

%----Constraints----
% Viewpoint 1: #produced-spacecrafts of type t is no less than #ordered-spacecrafts of type t
constraint forall(t in TYPES, w in WEEKS)(
    % #spacecrafts of type t are produced for every week
    count([typePlan[i] * typeStatus[i] | i in 1..w], t) 
    >= 
    % #spacecrafts of type t were ordered up until and including that week
    count([Order[t,i] | i in 1..w], 1)
);
% Viewpoint 2: At most one spacecraft can be assembled per week
constraint alldifferent(weekPlan) :: domain; % consistency
% Viewpoint 2: The due week of order o of spacecraft is specified, so weekPlan is sorted increasingly
constraint increasing(weekPlan) :: domain;
% Viewpoint 2: #produced-order of spacecraft of type t is no less than #original-order of spacecrafts of type t
constraint forall(t in TYPES, w in WEEKS)(
    % #produced-order of spacecraft of type t
    sum([bool2int(weekPlan[o] <= w /\ craftType[o] = t) | o in ORDERS])
    >= 
    % #original-order of spacecraft of type t
    sum([Order[t,i] | i in 1..w])
);

%----Chanelling constraints-----
% for every orders, the spacecraft type to assemble at the week that order o is due MUST BE the same as the spacecraft type of order o
constraint forall(o in ORDERS)(typePlan[weekPlan[o]] == craftType[o]);
% for every week, either a spacecraft is produced in both viewpoint 1 and 2, otherwise constrain that the order o of spacecraft is not produced at week w in viewpoint 2.
constraint forall(w in WEEKS)(
    typeStatus[w] = 1 
    \/ 
    (forall(o in ORDERS)(weekPlan[o] != w))
);

%----Objective----
% Viewpoint 1: the sum of all storage cost of the spacecrafts that are completed before their due date
allStorageCost = 
    % the sum of #extra-spacecrafts which is equivalent to #stored-week
    (sum(t in TYPES, w in WEEKS)(
        % the #produced-spacecraft of type t
        count([typePlan[i] * typeStatus[i] | i in 1..w], t) 
        - 
        % the #ordered-spacecraft of type t
        count([Order[t,i] | i in 1..w], 1)))
    * storageCost;
% Viewpoint 1: the sum of all adaptation cost of the factory when switching between spacecraft types
allSetupCost = sum(w in 1..weeks-1)(SetupCost[typePlan[w], typePlan[w+1]]);
% Viewpoint 2: the sum of all adaptation cost of the factory when switching between spacecraft types
constraint allSetupCost = sum([SetupCost[craftType[o], craftType[o+1]] | o in 1..numOrders-1]);
% Viewpoint 2: the sum of storage cost for every week based on multiplying storageCost by the difference between produced-order of spacecrafts and original-order.
constraint allStorageCost = 
    (sum(w in WEEKS)(
        % #produced-order of spacecrafts
        sum([bool2int(weekPlan[o] <= w) | o in ORDERS])
        -
        % #original-order of spacecrafts
        sum([Order[t,w] | w in 1..w, t in TYPES])
        )
    ) * storageCost;
% the construction of more complex search strategies
solve            
  :: seq_search([int_search(weekPlan, first_fail, indomain_min, complete),
                 int_search(craftType, first_fail, indomain_min, complete)]) 
  minimize allSetupCost + allStorageCost;

%----Output----
output [%----Output: Viewpoint 1----
        "Type per week: " ++ show(typePlan) ++ "\n" ++
        "Type status: " ++ show(typeStatus) ++ "\n" ++
        %----Output: Viewpoint 2----
        "Craft type: " ++ show(craftType) ++ "\n" ++
        "Week plan: " ++ show(weekPlan) ++ "\n" ++
        %----Output total cost----
        "Total cost: " ++ show(allSetupCost + allStorageCost)];
