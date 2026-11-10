#define N 3 // numero de clientes
#define CAP 10 // capital inicial del banco
short max[N] = {2, 4, 3}; // dinero máximo que necesita cada cliente
short loan[N] = 0; // cantidad prestada a cada cliente
short cash=CAP; // dinero disponible en el banco, inicialmente CAP

proctype Request(short amount) {
    if
    :: (amount <= max[__pid]) -> 
        if
        :: (amount <= cash) -> 
            loan[__pid] = amount;
            cash = cash - amount;
            req: printf("C%d requests %d. %d:[%d, %d, %d]\\n", __pid, amount, cash, loan[0], loan[1], loan[2]);
        :: else -> 
            printf("C%d requests %d. Not enough cash!\\n", __pid, amount);
        fi
    :: else -> 
        printf("C%d requests %d. Exceeds maximum!\\n", __pid, amount);
    fi
}

// proctype WithdrawMoney() {
//     short amount;
//     amount = (short) (1 + (rand() % 4)); // cantidad aleatoria entre 1 y 4
//     Request(amount);
// }

proctype Return(short amount) {
    if
    :: (quantity <= loan[__pid]) -> 
        loan[__pid] = loan[__pid] - quantity;
        cash = cash + quantity;
        ret: printf("C%d returns %d. %d:[%d, %d, %d]\\n", __pid, quantity, cash, loan[0], loan[1], loan[2]);
    :: else -> 
        printf("C%d tries to return %d. Not enough loan!\\n", __pid, quantity);
    fi
}

init {
}