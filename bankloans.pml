// Nombres de los alumnos aqui

#define N 3
#define CAP 10

short max[N] = {2, 4, 3};   // Dinero maximo que necesita cada cliente
short loan[N] = 0;          // Cantidad prestada actualmente a cada cliente
short cash = CAP;           // Dinero disponible en el banco (inicialmente CAP)

active [N] proctype Client() {
    short request;
    short returned;

    do
    // 1. Pedir dinero (si aun no ha alcanzado su maximo)
    :: (loan[_pid] < max[_pid]) ->
        // Eleccion no determinista de request en [1 .. max[_pid] - loan[_pid]]
        atomic {
            request = 1;
            do
            :: (request < max[_pid] - loan[_pid]) -> request++
            :: break
            od;
        }

        req: printf("C%d requests %d.   %d:[%d,%d,%d]\n",
                    _pid, request, cash, loan[0], loan[1], loan[2]);

        // Esperar hasta que haya suficiente cash y transferir de forma atomica
        atomic {
            (cash >= request) ->
            cash = cash - request;
            loan[_pid] = loan[_pid] + request;
            printf("C%d got the money %d.   %d:[%d,%d,%d]\n",
                   _pid, request, cash, loan[0], loan[1], loan[2]);
            assert(cash + loan[0] + loan[1] + loan[2] == CAP);
        }
        pay: skip;

    // 2. Devolver todo el prestamo actual (si tiene algo prestado)
    :: (loan[_pid] > 0) ->
        atomic {
            returned = loan[_pid];
            cash = cash + returned;
            loan[_pid] = 0;
            printf("C%d returns its loan %d.   %d:[%d,%d,%d]\n",
                   _pid, returned, cash, loan[0], loan[1], loan[2]);
            assert(cash + loan[0] + loan[1] + loan[2] == CAP);
        }
    od
}

// Objetivo 2: Safety
ltl safety_cash { [] (cash >= 0 && cash <= CAP) }

ltl safety_loan {
    [] (loan[0] >= 0 && loan[0] <= max[0] &&
        loan[1] >= 0 && loan[1] <= max[1] &&
        loan[2] >= 0 && loan[2] <= max[2])
}

// Objetivo 3: Liveness (ausencia de starvation)
ltl liveness0 { [] (Client[0]@req -> <> Client[0]@pay) }
ltl liveness1 { [] (Client[1]@req -> <> Client[1]@pay) }
ltl liveness2 { [] (Client[2]@req -> <> Client[2]@pay) }