# Reporte de revisión: `bankloans.pml` frente al enunciado y la teoría

> Documento de trabajo interno, no es el informe de entrega. Explica qué hace el código, si cumple el enunciado (`VVS.pdf` / `Enunciado.pdf`) y la teoría (`teoria/T3-Spin.pdf`, `teoria/T4-LTL.pdf`), y cómo ejecutar SPIN para obtener los resultados de cada objetivo.
>
> Todos los resultados de este documento se han obtenido ejecutando **SPIN 6.5.2** en esta máquina (23/11/2026).

---

## 0. Resumen rápido

| Aspecto | Estado |
|---|---|
| Estructura del modelo (un proceso por cliente, pedir/devolver, `atomic`) | ✅ Correcta |
| Etiquetas `req` (petición) y `pay` (pago) | ✅ Correctas y bien situadas |
| Assert de la suma `cash+loan[0]+loan[1]+loan[2]==CAP` tras cada transferencia | ✅ Correcto |
| Fórmulas LTL de safety y liveness | ✅ Correctas |
| **`max = {5,4,3}` y `CAP = 4`** | ❌ **No coincide con el enunciado** (`max={2,4,3}`, `CAP=10`), e incumple `max[i] <= CAP` |
| **`CAP` no se puede cambiar desde la línea de comandos** | ❌ `#define CAP 4` sin `#ifndef`: `-DCAP=6` se ignora |
| Detección de deadlock con las `ltl` en el fichero | ⚠️ Con una `ltl` activa, pan **no comprueba** estados finales inválidos (deadlock). Hay que compilar con `-DNOCLAIM` |
| Espacio de estados | ⚠️ Muy grande (2,3 M estados y profundidad 1,29 M con CAP=7) porque `request`/`returned` guardan valores antiguos. Incluso `-m1000000` del enunciado se queda corto |
| Nombres de los alumnos | ❌ Falta (`// Nombres de los alumnos aqui`) |

Con los dos fallos críticos corregidos (valores del enunciado y `CAP` configurable) el modelo da los resultados esperados por la teoría:

- **Deadlock:** existe para `CAP = 0..6` y no existe para `CAP >= 7`, así que **x = 6**.
- **Safety (CAP = 7):** se cumplen las tres propiedades (0 errores).
- **Liveness (CAP = 7):** **no se cumple** para ningún cliente: hay inanición (starvation) bajo weak fairness.

---

## 1. Qué pide el enunciado

Hay un banco con capital `CAP` y `N = 3` clientes con `max = {2,4,3}`. El banco no se modela como proceso: cada cliente toma el dinero directamente de `cash`.

Cada cliente, en bucle, puede:

1. **Pedir**, si `loan[i] < max[i]`, una cantidad arbitraria en `1 .. max[i]-loan[i]`. Imprime `req: printf("C%d requests %d. ...")`, espera hasta que `cash` sea suficiente, retira el dinero e imprime `C%d got the money %d. ...`.
2. **Devolver todo** su préstamo, si `loan[i] > 0`, e imprimir `C%d returns its loan %d. ...`.

- **Advertencia 1:** cada transferencia modifica `cash` y `loan[i]`, y ningún otro proceso puede intervenir en medio. Por eso se usa `atomic`.
- **Advertencia 2:** si aparece `error: max search depth too small`, hay que subir `-m`.

Objetivos:

1. **Deadlock:** probar `CAP = 10` y valores menores, encontrar el `CAP` máximo `x` con deadlock, y sacar y explicar una traza para `CAP = x`.
2. **Safety con `CAP = x+1`:**
   - `0 <= cash <= CAP`
   - `0 <= loan[i] <= max[i]`
   - `cash + Σloan == CAP` tras cada transferencia, comprobado con `assert`.
3. **Liveness:** comprobar que toda petición acaba pagándose, usando etiquetas, y explicar el contraejemplo si lo hay.

Hay que entregar un `.zip` con el `.pml` y un informe en PDF o texto ASCII, con los nombres de los alumnos en las primeras líneas de cada fichero.

---

## 2. Explicación del código, bloque a bloque

### 2.1 Variables globales

```promela
#define N 3
#define CAP 4
short max[N] = {5, 4, 3};
short loan[N] = 0;
short cash = CAP;
```

- `loan[N] = 0` inicializa todo el array a 0.
- `cash` empieza con todo el capital.
- ❌ El enunciado fija `max = {2,4,3}` y `CAP = 10`, y además exige `0 < max[i] <= CAP`. Con `max[0]=5` y `CAP=4` se incumple esa condición: el cliente 0 nunca podría llegar a su máximo. Todos los resultados (el valor de x, las trazas…) cambian, así que **hay que volver a `{2,4,3}`**.

### 2.2 Procesos cliente

```promela
active [N] proctype Client() {
    short request;
    short returned;
```

- `active [N]` crea 3 copias del proceso al arrancar, con `_pid = 0, 1, 2` (T3, "Multiple copies of processes").
- Por eso los mensajes salen como `C0, C1, C2`. En el ejemplo del enunciado aparece `C1` porque allí se crean desde `init`, que ocupa el pid 0. No es un error, pero tenedlo en cuenta al explicar las trazas.
- En las fórmulas, `Client[0]` es el proceso con `_pid` 0 (sintaxis `procname[pid]@label`, T3 pág. 50).

### 2.3 Opción 1: pedir dinero

```promela
    :: (loan[_pid] < max[_pid]) ->
        atomic {
            request = 1;
            do
            :: (request < max[_pid] - loan[_pid]) -> request++
            :: break
            od;
        }
```

- La guarda solo deja pedir si no se ha alcanzado el máximo.
- El `do` interno elige **de forma no determinista** un valor entre `1` y `max-loan`: en cada vuelta puede incrementar o salir. Es el mismo patrón del ejercicio "try to get 100" de T3 (pág. 24) y equivale a `select(request : 1 .. max[_pid]-loan[_pid])`.
- Va dentro de `atomic` para que la elección cuente como un solo paso y no multiplique los entrelazados. ✅

```promela
        req: printf("C%d requests %d.   %d:[%d,%d,%d]\n", ...);
```

- La etiqueta `req` marca el punto de la petición, como pide el enunciado. ✅

```promela
        atomic {
            (cash >= request) ->
            cash = cash - request;
            loan[_pid] = loan[_pid] + request;
            printf("C%d got the money %d. ...");
            assert(cash + loan[0] + loan[1] + loan[2] == CAP);
        }
        pay: skip;
```

- **Espera:** `(cash >= request)` es una sentencia bloqueante. El proceso se queda parado hasta que sea cierta. Al ser la primera sentencia del `atomic`, el bloque solo empieza cuando hay dinero. Es el mismo patrón que `wait(sem)` en T3 (págs. 43‑44). ✅
- **Advertencia 1:** la resta de `cash` y la suma de `loan` van en el mismo `atomic`, así que ningún otro cliente puede ver el estado intermedio. ✅
- **Assert de la suma:** está al final del bloque atómico, es decir, *después* de la transferencia, como pide el enunciado. ✅
- **`pay: skip`:** marca el punto en el que el cliente ya ha recibido el dinero, y es la etiqueta que usa la fórmula de liveness. ✅

**Importante sobre el bloqueo.** El cliente que está esperando en `(cash >= request)` **no puede devolver** su préstamo, porque la opción "devolver" solo se elige al principio del `do`. Esta es la clave del deadlock (ver §5.1).

### 2.4 Opción 2: devolver el préstamo

```promela
    :: (loan[_pid] > 0) ->
        atomic {
            returned = loan[_pid];
            cash = cash + returned;
            loan[_pid] = 0;
            printf("C%d returns its loan %d. ...");
            assert(cash + loan[0] + loan[1] + loan[2] == CAP);
        }
```

Se devuelve **todo** el préstamo, de forma atómica, y se comprueba la suma. ✅

Si ambas guardas son ciertas (`0 < loan < max`), SPIN elige cualquiera de las dos de forma no determinista. Eso es justo lo que modela "puede devolver en cualquier momento". Cuando `loan == max`, solo la opción 2 está activa, así que el cliente está obligado a devolver.

### 2.5 Propiedades LTL

```promela
ltl safety_cash { [] (cash >= 0 && cash <= CAP) }
ltl safety_loan { [] (loan[0] >= 0 && loan[0] <= max[0] && ... ) }
ltl liveness0 { [] (Client[0]@req -> <> Client[0]@pay) }   // y 1, 2
```

- `[] p` significa "siempre p" (invariante). Son las dos primeras propiedades de safety. ✅
- `[] (req -> <> pay)` significa "siempre que se pida, en algún momento futuro se paga" (T4, propiedad de respuesta). ✅
- SPIN niega cada fórmula y la convierte en un *never claim* (autómata de Büchi, T4). Lo podéis ver en `_spin_nvr.tmp`.
- **Solo se verifica una fórmula por ejecución.** Se elige con `./pan -N nombre`. Si no se indica, se usa la primera (`safety_cash`).

---

## 3. Conceptos de la teoría que intervienen

| Concepto | Dónde | Cómo aparece aquí |
|---|---|---|
| `spin -a` → `pan.c` → `gcc` → `./pan` | T3 p.23 | Verificación exhaustiva |
| Traza `.trail` y `spin -t -p` | T3 p.23 | Reproducir contraejemplos |
| `-m` profundidad máxima | T3 p.25 y enunciado | Imprescindible: el modelo es profundo |
| `atomic` | T3 pp.43‑44 (semáforos) | Transferencias indivisibles |
| Deadlock = timeout = "invalid end state" | T3 p.39 | Todos los clientes bloqueados en `cash >= request` |
| `-E` ignora deadlocks | T3 p.43 | Útil si solo queréis ver la propiedad |
| Etiquetas y `proc[pid]@label` | T3 p.50 | `Client[i]@req`, `Client[i]@pay` |
| `pan -a -f`: ciclos de aceptación con weak fairness | T3 p.50 | Liveness. La traza muestra `START OF CYCLE` |
| Weak fairness: `◇□enabled → □◇executed` | T4 p.29 | Explica por qué hay inanición aunque el cliente esté habilitado a ratos |

---

## 4. Problemas detectados y cómo corregirlos

### 4.1 ❌ Crítico: valores de `max` y `CAP`

Sustituid por los del enunciado y permitid cambiar `CAP` con `-D`:

```promela
#define N 3
#ifndef CAP
#define CAP 10
#endif
short max[N] = {2, 4, 3};
```

Sin el `#ifndef`, `spin -a -DCAP=6 bankloans.pml` avisa con `'CAP' macro redefined` y **se queda con el valor del fichero**. Las pruebas con distintos CAP no servirían.

### 4.2 ⚠️ Deadlock y never claims

Con alguna `ltl` en el fichero, pan muestra:

```
invalid end states	- (disabled by never claim)
```

Es decir, **no busca deadlocks**. Para el objetivo 1 hay que compilar sin claim:

```bash
gcc -DNOCLAIM -o pan pan.c
```

Otra opción es meter las `ltl` dentro de `#ifdef LTL ... #endif`, como en `example.pml`. Nota: la opción `./pan -noclaim` no funcionó en esta versión de SPIN, así que usad `-DNOCLAIM`.

### 4.3 ⚠️ Explosión de estados (recomendado arreglarlo)

`request` y `returned` conservan su último valor, así que dos estados idénticos en lo que importa cuentan como distintos. Basta con reiniciarlas dentro de los `atomic`:

```promela
            printf("C%d got the money ...");
            request = 0;                       // <-- añadir
            assert(cash + loan[0] + loan[1] + loan[2] == CAP);
        }
...
            loan[_pid] = 0;
            returned = 0;                      // <-- añadir
```

Resultados medidos sin `ltl` (`-DNOCLAIM`):

| CAP | Sin reiniciar | Reiniciando |
|---|---|---|
| 6 | 13 719 estados, deadlock a profundidad 19 474 | 1 437 estados, deadlock a profundidad 1 864 |
| 7 | **2 302 832 estados, profundidad 756 783** (con `ltl`: 1 292 416) | **13 686 estados, profundidad 10 996** |

Sin este cambio, con `CAP = 7`, tanto el `-m` por defecto (10 000) como el `-m1000000` del enunciado dan `error: max search depth too small`. Hace falta `-m10000000`.

### 4.4 Menores

- Poned los **nombres de los alumnos** en la primera línea (el enunciado lo exige).
- Los ficheros `pan.*`, `_spin_nvr.tmp` y `*.trail` son generados. Conviene no incluirlos en el `.zip` y añadirlos al `.gitignore`.
- Opcional: `select(request : 1 .. max[_pid]-loan[_pid]);` hace lo mismo que vuestro `do` y se lee mejor.

---

## 5. Resultados obtenidos (con `max={2,4,3}` y `CAP` configurable)

### 5.1 Objetivo 1: deadlock

Comando para cada `CAP`:

```bash
spin -a -DCAP=$c bankloans.pml && gcc -w -DNOCLAIM -o pan pan.c && ./pan -m10000000
```

| CAP | ¿Deadlock? | Estados almacenados |
|---|---|---|
| 0 | sí | 10 |
| 1 | sí | 10 |
| 2 | sí | 239 |
| 3 | sí | 479 |
| 4 | sí | 1 077 |
| 5 | sí | 2 707 |
| **6** | **sí** | 13 719 |
| 7 | no | 2 302 832 |
| 8 | no | 2 430 272 |
| 9 | no | 2 469 152 |
| 10 | no | 2 469 152 |

**Resultado: x = 6.**

**Comprobación analítica.** En un deadlock, los tres clientes esperan con una petición `r_i > cash` y cumplen `loan_i + r_i <= max_i`. Por tanto `loan_i <= max_i - cash - 1`. Sumando para los tres clientes, con `Σmax = 9` y `Σloan = CAP - cash`:

```
CAP - cash <= 9 - 3(cash + 1)   ⇒   CAP <= 6 - 2·cash
```

El máximo se alcanza con `cash = 0`, y da **CAP = 6**. Coincide con SPIN.

**Traza más corta para CAP = 6.** Se obtiene con búsqueda en anchura:

```bash
spin -a -DCAP=6 bankloans.pml && gcc -w -DNOCLAIM -DBFS -o pan pan.c && ./pan
spin -DCAP=6 -t bankloans.pml        # añadir -p para ver cada paso
```

```
C2 requests 2.          6:[0,0,0]
C2 got the money 2.     4:[0,0,2]
C2 requests 1.          4:[0,0,2]
C1 requests 3.          4:[0,0,2]
C1 got the money 3.     1:[0,3,2]
C1 requests 1.          1:[0,3,2]
C0 requests 1.          1:[0,3,2]
C0 got the money 1.     0:[1,3,2]
C0 requests 1.          0:[1,3,2]    <-- deadlock (timeout)
```

**Explicación.** El banco se queda con `cash = 0` y los préstamos son `[1,3,2]`. Cada cliente está a 1 € de su máximo (`{2,4,3}`) y ya ha pedido ese euro, así que los tres están parados en la guarda `cash >= request`.

Ninguno puede devolver lo que tiene, porque solo se puede devolver desde el principio del bucle, y para volver ahí tendrían que recibir antes el dinero. Es una espera circular: todo el capital está repartido y cada cliente espera lo que tienen los demás. Es el "estado inseguro" que el algoritmo del banquero de Dijkstra evitaría rechazando, por ejemplo, la petición de 3 € de C1.

> Con DFS normal (sin `-DBFS`), la traza tiene unos 19 000 pasos. Sirve igual, pero es ilegible. Para el informe usad `-DBFS`. La opción `./pan -i` (acortamiento iterativo) resultó demasiado lenta aquí.

### 5.2 Objetivo 2: safety (CAP = x+1 = 7)

```bash
spin -a -DCAP=7 bankloans.pml && gcc -w -o pan pan.c
./pan -m10000000 -N safety_cash
./pan -m10000000 -N safety_loan
```

| Propiedad | Mecanismo | Resultado |
|---|---|---|
| `0 <= cash <= CAP` | `ltl safety_cash` | ✅ `errors: 0` (2 302 832 estados) |
| `0 <= loan[i] <= max[i]` | `ltl safety_loan` | ✅ `errors: 0` |
| `cash + Σloan == CAP` tras cada transferencia | `assert` en los `atomic` | ✅ Ningún assert violado. Se comprueban en ambas ejecuciones y también en la de deadlock |

Además, con CAP = 7 no hay deadlock (tabla anterior).

La suma solo deja de ser `CAP` *dentro* de un `atomic`, entre la resta de `cash` y la suma de `loan`. Como el bloque es atómico, ningún otro proceso ve ese estado. Por eso el assert va al final del bloque y no se puede escribir como `[]` en LTL.

### 5.3 Objetivo 3: liveness / inanición (CAP = 7)

```bash
spin -a -DCAP=7 bankloans.pml && gcc -w -o pan pan.c
./pan -a -f -m10000000 -N liveness0    # repetir con liveness1 y liveness2
spin -DCAP=7 -t -p bankloans.pml       # muestra <<<<<START OF CYCLE>>>>>
```

| Fórmula | Resultado |
|---|---|
| `liveness0` (C0) | ❌ acceptance cycle |
| `liveness1` (C1) | ❌ acceptance cycle |
| `liveness2` (C2) | ❌ acceptance cycle |

**Contraejemplo obtenido para `liveness2` (resumido):**

```
C2 requests 3.          7:[0,0,0]     <-- C2 pide 3 € y nunca los recibirá
C1 requests 4.          7:[0,0,0]
C1 got the money 4.     3:[0,4,0]
C1 returns its loan 4.  7:[0,0,0]
...
  <<<<<START OF CYCLE>>>>>
C1 returns its loan 4.  5:[2,0,0]
C1 requests 4.          5:[2,0,0]
C1 got the money 4.     1:[2,4,0]
C0 returns its loan 2.  3:[0,4,0]
C1 returns its loan 4.  7:[0,0,0]
C1 requests 4.          7:[0,0,0]
C1 got the money 4.     3:[0,4,0]
C0 requests 2.          3:[0,4,0]
C0 got the money 2.     ...
(se repite indefinidamente)
```

**Explicación.** C2 pide 3 € y se queda esperando. Mientras tanto, C1 y C0 piden y devuelven una y otra vez, y `cash` va cambiando entre 7, 5, 3 y 1.

En algunos momentos (`cash >= 3`) C2 podría avanzar, pero su guarda **no está habilitada de forma continua**: se desactiva cada vez que `cash` baja de 3. Weak fairness (`pan -f`, T4 p.29: `◇□enabled → □◇executed`) solo obliga a ejecutar procesos habilitados *permanentemente*. Por tanto esta ejecución infinita es justa en sentido débil y aun así C2 no cobra nunca.

La causa es que el banco no tiene cola ni prioridad: cuando hay dinero, gana el primero que se planifica. Que no haya deadlock (CAP >= 7) **no implica** que no haya inanición.

**Comprobación extra:** con `CAP = 9` (= Σmax, nadie espera nunca), `liveness2` da `errors: 0` (3,7 M estados). La inanición desaparece solo cuando el capital cubre todos los máximos a la vez.

---

## 6. Guía de ejecución paso a paso

Trabajad en una carpeta aparte para no ensuciar el repositorio con `pan.*`:

```bash
mkdir -p out && cp bankloans.pml out/ && cd out
```

### 6.1 Simulación (comprobar a ojo que los `printf` tienen sentido)

```bash
spin -DCAP=7 -u300 bankloans.pml        # aleatoria, 300 pasos
spin -DCAP=7 -u300 -n42 bankloans.pml   # semilla fija, reproducible
```

### 6.2 Barrido de deadlock (objetivo 1)

```bash
for c in 0 1 2 3 4 5 6 7 8 9 10; do
  spin -a -DCAP=$c bankloans.pml >/dev/null
  gcc -w -DNOCLAIM -o pan pan.c
  echo "CAP=$c: $(./pan -m10000000 | grep -E 'errors:|invalid end state' | tr '\n' ' ')"
  rm -f *.trail
done
```

Luego sacad la traza corta para `CAP = 6` (ver §5.1).

### 6.3 Safety (objetivo 2)

Ver §5.2. Comprobad en la salida:

- `errors: 0`
- `assertion violations +`
- que **no** aparezca `max search depth too small`

### 6.4 Liveness (objetivo 3)

Ver §5.3. Usad **siempre `-a -f`**: `-a` busca ciclos de aceptación y `-f` activa weak fairness. Sin `-f` aparecerían contraejemplos "tramposos" en los que el cliente simplemente nunca se planifica.

Si con `CAP <= 6` queréis ver solo la inanición y no el deadlock, añadid `-E`.

### 6.5 Cómo leer la salida de pan

| Mensaje | Significado |
|---|---|
| `errors: 0` | Propiedad verificada en todo el espacio de estados |
| `invalid end state` | Deadlock |
| `assertion violated` | Ha fallado un `assert` o una `ltl` de safety |
| `acceptance cycle` | Falla una propiedad de liveness (ejecución infinita) |
| `max search depth too small` | **El resultado no es fiable.** Subid `-m` |
| `invalid end states - (disabled by never claim)` | En esta ejecución no se buscan deadlocks |

Las trazas se reproducen con `spin -DCAP=<mismo valor> -t -p bankloans.pml`. Usad **el mismo `-DCAP`** con el que se generó el `.trail`.

---

## 7. Checklist antes de entregar

- [ ] `max = {2,4,3}` y `#ifndef CAP / #define CAP 10 / #endif`
- [ ] Nombres de los alumnos en la primera línea del `.pml` y del informe
- [ ] (Recomendado) reiniciar `request` y `returned`
- [ ] Tabla de deadlock CAP = 0..10 con x = 6, traza BFS y su explicación
- [ ] Safety con CAP = 7: salida de pan con `errors: 0` para las dos `ltl` y los asserts
- [ ] Liveness con CAP = 7: contraejemplo con `START OF CYCLE` y su explicación (weak fairness)
- [ ] Informe en PDF o texto ASCII (este `.md` es solo de apoyo) y `.zip` sin `pan.*` ni `*.trail`
