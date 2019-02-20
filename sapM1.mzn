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
set of int: TYPES = 1..types; % index range of types of spacecraft
set of int: WEEKS = 1..weeks; % index range of weeks

%----Decision variables----
% all adaptation cost of the factory when switching between spacecraft types
var 0..maxCost: allSetupCost;
% all storage cost of the spacecrafts that are completed before their due date
var 0..maxCost: allStorageCost; 
% total cost
var 0..maxCost: totalCost;
% typePlan[w] = spacecrafts of that type to assemble at week w
array[WEEKS] of var TYPES: typePlan;
% typeStatus[w] = 0 or 1 spacecraft is assembled at week w
array[WEEKS] of var 0..1: typeStatus;

%----Constraints----
% #produced-spacecrafts of type t is no less than #ordered-spacecrafts of type t
constraint forall(t in TYPES, w in WEEKS)(
    % #spacecrafts of type t are produced for every week
    count([typePlan[i] * typeStatus[i] | i in 1..w], t) 
    >= 
    % #spacecrafts of type t were ordered up until and including that week
    count([Order[t,i] | i in 1..w], 1)
);

%----Objective----
% the sum of all storage cost of the spacecrafts that are completed before their due date
constraint allStorageCost = 
    % the sum of #extra-spacecrafts which is equivalent to #stored-week
    (sum(t in TYPES, w in WEEKS)(
        % the #produced-spacecraft of type t
        count([typePlan[i] * typeStatus[i] | i in 1..w], t) 
        - 
        % the #ordered-spacecraft of type t
        count([Order[t,i] | i in 1..w], 1)))
    * storageCost;

% the sum of all adaptation cost of the factory when switching between spacecraft types
constraint allSetupCost = sum(w in 1..weeks-1)(SetupCost[typePlan[w], typePlan[w+1]]);

% the sum of all costs
constraint totalCost = allSetupCost + allStorageCost; 

solve 
  :: seq_search([int_search(typePlan, occurrence, indomain_min, complete),
                 int_search(typeStatus, occurrence, indomain_min, complete)]) 
  minimize totalCost;

%----Output----
output ["Type per week: " ++ show(typePlan) ++ "\n" ++
        "Type status: " ++ show(typeStatus) ++ "\n" ++
        "Total cost: " ++ show(totalCost)];
