## VVS: model checking 

# Bank loans 

#### Introduction 

In this exercise we will play with a variation of a classical example of concurrency problem proposed by E. W. Dijkstra in 1982 that led to the design of the Banker's algorithm.We will use here the simplest case where the Banker's algorithm isnot being applied. 

AAciven bank with an inital capital ar>o of money has 3 clients. Each client is allowed to ask for loans up toa given predefined maximum maxi of total loan where cnx} <-ear. The client may retum al the money borrowed so farat any moment. On the other hand, one a client reaches its maximum loan, it cannot ask for further money 0 she can only retum her money ina finite time, cancelling the loan 

Implementation in Promela We will model each client as a different process. The bank will not be modeled: instead, each client wil withdraw from the bank cash the money she requests, whenever she gets the chance. We wil fix we3 clients and define the fllowing structures: 

raibal variables tcetine x 3 {aetine car 10 hort max{w=(2,4,3); // Maxim money needed by exch client Short caahteaPy 11 Noney inthe bank (initially, the capital CAP) 

“The client can do one ofthe following operations: 

1. chosen,If the client the program has not reached herwil do the operation maximum loan, she can request any arbitrary amount from 1 euro to the remaining money to gether maximum loan. When a money request is 

req peinte("evd requests 14. 4:(44,44,44)\n", _pld, request, cash, Loan{O},leas(2},1o00(21)5 

to inform about her wish to get more money. Note tht this print has the label reg An example would be: 

‘The client will wait until there is enough cash, and proceed to take her request adding i to her current loan, When the client gets the requested money, she also prints a message ike 

1 got the money 2. 4:12/3/11 

2. Ifthe client has any loan greater than O, she can return it at any moment, When doing soit will make a print ike, fr instance 

Warning 1: any money transfer (ether an income ora payment plies modifying the cash and the clea’ acount Loan. Sine both modifications cannot be done i a same assignment, you will have to guarantee thatthe two operations ae blacked in such a way that no other process can make changes to those variables inthe middle ofthe transfer. Warning2: when you run SPIN in verification mode and execute the program analyzer pan py tention to eror messages of the form 

ervoes nam search depth tov sual 

Ir this happens, there might be erors not detected, otto increas the search depth using the option -m ike, fr instance, in 

### Goals 

- ‘We wil prove the following properties trying with dfferet input configurations: |. abwence of deadlock: we cannot reach a state in which ll clients get blocked requesting more money andthe bank has not enough cash to lend ©. Make tries with car-i0 and lower. Obviously, if we start car-o we will gta deadlock (ther is no initial money at all). Find the maximum car value x for which you can acta deadlock. 

- «Get some deadlock trace for ear=x and explain it: focus onthe lst operations ofeach process and the current sats ofthe cash and the cients accounts 

- 2. safety: fixing car=xe1 check ©66 eachtheaftersimply cash accounteach useisalays anbank toan{ asserttransfer, between1} foristhe alwayscheckthisfollowing oand propery,thatthebetween car propertiessumo andcasheoun{0]*Loan(1}+Lean(2}mex{41 is equal to car (note that, during the transfer, this may be momentarily violated). You can 

- 3. liveness (lack of starvation): check if for any client , when she makes a reques, se will eventually get a payment. Use instruction labels to name the points inthe code where a request and a payment i done. If you find a counterexample (iat sa east one client not satisfying this property) explain the obtained race 

### Assessment & delivery 

> ‘Thewith pmlmaximum code andgrade report,for this inexercisePDF oris pan2 points, ASCHUseformat.campusvirtualhtp:/isconlin.udeThe report must explain the experimentsgall platform you performed(pctca SPIN). to checkUploadthe propertisyour work aas tatedsingle above,zip andfile thecontaining obtainedallresultsthe files in ‘ich case, Exercises can be made by two students at most ifs, the students names must Be included inthe fist ines ofeach file and only one of the students needs to upload the fies toils campusvirial account 

“The deadline for delivery is Friday, December 11th, 2026 (23:59). 

