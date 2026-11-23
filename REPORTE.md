# Reporte de revisión: `codigo/bankloans.pml` frente al enunciado y la teoría

> Documento de trabajo interno, no es el informe de entrega. Explica qué hace el código, si cumple el enunciado (`enunciado/VVS.pdf` / `enunciado/Enunciado.pdf`) y la teoría (`teoria/T3-Spin.pdf`, `teoria/T4-LTL.pdf`), y cómo ejecutar SPIN para obtener los resultados de cada objetivo.
>
> Todos los resultados se han obtenido ejecutando **SPIN 6.5.2** en esta máquina. Última revisión: 23/11/2026, sobre el commit `6320d0c organizacion`.

### Estructura del repositorio

```
codigo/bankloans.pml      modelo Promela (lo que se entrega)
enunciado/                Enunciado.pdf (español) y VVS.pdf (inglés, misma práctica)
teoria/                   T1..T5 (ignorada por git)
ejemplo/                  example.pml / examplereport.txt (ignorada por git)
REPORTE.md                este documento
```

---

## 0. Resumen rápido

| Aspecto | Estado |
|---|---|
| Nombres de los alumnos al principio del fichero | ✅ Corregido |
| `max = {2,4,3}` y `CAP = 10` como en el enunciado | ✅ Corregido |
| Estructura del modelo (un proceso por cliente, pedir/devolver, `atomic`) | ✅ Correcta |
| Etiquetas `req` (petición) y `pay` (pago) | ✅ Correctas |
| Assert de la suma tras cada transferencia | ✅ Correcto |
| Fórmulas LTL de safety y liveness | ✅ Correctas |
| `request = 0` tras cobrar | ✅ Añadido. Reduce los estados con CAP=7 de 2,3 M a 821 K |
| **`CAP` sigue sin poder cambiarse con `-DCAP=…`** | ❌ **Pendiente.** `spin -a -DCAP=6` sigue verificando con CAP=10 (comprobado) |
| `returned = 0` tras devolver | ⚠️ Pendiente (recomendado). Con él, CAP=7 baja a 13,7 K estados |
| Detección de deadlock con `ltl` en el fichero | ⚠️ Hay que compilar con `-DNOCLAIM` (es una cuestión de cómo se ejecuta, no del código) |

Los veredictos con el código actual no cambian respecto a la revisión anterior:

- **Deadlock:** existe para `CAP = 0..6` y no existe para `CAP >= 7`, así que **x = 6**.
- **Safety (CAP = 7):** se cumplen las tres propiedades.
- **Liveness (CAP = 7):** **no se cumple** para ningún cliente; hay inanición bajo weak fairness.

---

## 1. Qué pide el enunciado

Hay un banco con capital `CAP` y `N = 3` clientes con `max = {2,4,3}`. El banco no se modela como proceso: cada cliente toma el dinero directamente de `cash`.

Cada cliente, en bucle, puede:

1. **Pedir**, si `loan[i] < max[i]`, una cantidad en `1 .. max[i]-loan[i]`. Imprime `req: printf("C%d requests %d. ...")`, espera hasta que haya efectivo suficiente, retira el dinero e imprime `C%d got the money %d. ...`.
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

Hay que entregar un `.zip` con el `.pml` y un informe en PDF o texto ASCII, con los nombres en las primeras líneas de cada fichero.

---

## 2. Explicación del código, bloque a bloque

### 2.1 Cabecera y variables globales (líneas 1‑9)

```promela
//Nicolas Lopez Robleda
//Lucas Rodriguez Lanza

#define N 3
#define CAP 10

short max[N] = {2, 4, 3};
short loan[N] = 0;
short cash = CAP;
```

- Los nombres y los valores ya coinciden con el enunciado. ✅
- `loan[N] = 0` inicializa todo el array a 0, y `cash` empieza con todo el capital.
- ❌ `#define CAP 10` sin `#ifndef`: ver §4.1.

### 2.2 Procesos cliente (líneas 11‑13)

```promela
active [N] proctype Client() {
    short request;
    short returned;
```

- `active [N]` crea 3 copias al arrancar, con `_pid = 0, 1, 2` (T3, "Multiple copies of processes").
- Por eso los mensajes salen como `C0, C1, C2`. En el enunciado aparece `C1` porque allí se crean desde `init`, que ocupa el pid 0. No es un error, pero tenedlo en cuenta al explicar las trazas.
- En las fórmulas, `Client[0]` es el proceso con `_pid` 0 (sintaxis `procname[pid]@label`, T3 pág. 50).

### 2.3 Opción 1: pedir dinero (líneas 17‑40)

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
- El `do` interno elige **de forma no determinista** un valor entre `1` y `max-loan`: en cada vuelta puede incrementar o salir. Es el patrón del ejercicio "try to get 100" de T3 (pág. 24) y equivale a `select(request : 1 .. max[_pid]-loan[_pid])`.
- Va dentro de `atomic` para que la elección cuente como un solo paso. ✅

```promela
        req: printf("C%d requests %d.   %d:[%d,%d,%d]\n", ...);
```

La etiqueta `req` marca el punto de la petición. ✅

```promela
        atomic {
            (cash >= request) ->
            cash = cash - request;
            loan[_pid] = loan[_pid] + request;
            printf("C%d got the money %d. ...");
            request = 0;
            assert(cash + loan[0] + loan[1] + loan[2] == CAP);
        }
        pay: skip;
```

- **Espera:** `(cash >= request)` es una sentencia bloqueante. El proceso se queda parado hasta que sea cierta. Al ser la primera sentencia del `atomic`, el bloque solo empieza cuando hay dinero. Es el mismo patrón que `wait(sem)` en T3 (págs. 43‑44). ✅
- **Advertencia 1:** la resta de `cash` y la suma de `loan` van en el mismo `atomic`, así que nadie ve el estado intermedio. ✅
- **`request = 0`:** se pone después del `printf`, que todavía necesita el valor. Así se olvida un dato que ya no hace falta y SPIN no distingue estados que en realidad son iguales (§4.2). ✅
- **Assert de la suma:** al final del bloque, es decir, *después* de la transferencia. ✅
- **`pay: skip`:** marca que el cliente ya ha recibido el dinero. Es la etiqueta que usa la fórmula de liveness. ✅

**Importante.** El cliente que está esperando en `(cash >= request)` **no puede devolver** su préstamo, porque solo se puede devolver desde el principio del `do`. Esta es la clave del deadlock (§5.1).

### 2.4 Opción 2: devolver el préstamo (líneas 43‑51)

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

- Se devuelve **todo** el préstamo, de forma atómica, y se comprueba la suma. ✅
- Si ambas guardas son ciertas (`0 < loan < max`), SPIN elige cualquiera de las dos. Eso modela "puede devolver en cualquier momento".
- Cuando `loan == max`, solo está activa la opción 2, así que el cliente está obligado a devolver.
- ⚠️ Aquí falta `returned = 0;` después del `printf` (§4.2).

### 2.5 Propiedades LTL (líneas 55‑67)

```promela
ltl safety_cash { [] (cash >= 0 && cash <= CAP) }
ltl safety_loan { [] (loan[0] >= 0 && loan[0] <= max[0] && ... ) }
ltl liveness0 { [] (Client[0]@req -> <> Client[0]@pay) }   // y 1, 2
```

- `[] p` significa "siempre p" (invariante). Son las dos primeras propiedades de safety. ✅
- `[] (req -> <> pay)` significa "siempre que se pida, en algún momento se paga" (T4, propiedad de respuesta). ✅
- SPIN niega cada fórmula y la convierte en un *never claim* (autómata de Büchi, T4).
- **Solo se verifica una fórmula por ejecución.** Se elige con `./pan -N nombre`. Si no se indica, se usa la primera (`safety_cash`).

---

## 3. Conceptos de la teoría que intervienen

| Concepto | Dónde | Cómo aparece aquí |
|---|---|---|
| `spin -a` → `pan.c` → `gcc` → `./pan` | T3 p.23 | Verificación exhaustiva |
| Traza `.trail` y `spin -t -p` | T3 p.23 | Reproducir contraejemplos |
| `-m` profundidad máxima | T3 p.25 y enunciado | Imprescindible: el modelo es profundo |
| `atomic` | T3 pp.43‑44 (semáforos) | Transferencias indivisibles |
| Deadlock = timeout = "invalid end state" | T3 p.39 | Todos bloqueados en `cash >= request` |
| `-E` ignora deadlocks | T3 p.43 | Para ver solo la propiedad |
| Etiquetas y `proc[pid]@label` | T3 p.50 | `Client[i]@req`, `Client[i]@pay` |
| `pan -a -f`: ciclos de aceptación con weak fairness | T3 p.50 | Liveness. La traza muestra `START OF CYCLE` |
| Weak fairness: `◇□enabled → □◇executed` | T4 p.29 | Explica la inanición aunque el cliente esté habilitado a ratos |

---

## 4. Problemas pendientes y cómo corregirlos

### 4.1 ❌ `CAP` no se puede cambiar desde la línea de comandos

Lo he comprobado con el código actual. `spin -a -DCAP=6 codigo/bankloans.pml` muestra el aviso `warning: 'CAP' macro redefined` y **verifica con CAP=10** (sale `errors: 0` y 832 500 estados, exactamente lo mismo que con CAP=10). Sin corregirlo, cualquier experimento con `-DCAP` es **silenciosamente incorrecto**.

**Solución recomendada** (dos líneas):

```promela
#ifndef CAP
#define CAP 10
#endif
```

Si no queréis tocar el código, la alternativa es editar a mano el `#define CAP` (o generar copias con `sed`, §6.2) para cada valor. Es más incómodo y más propenso a errores.

### 4.2 ⚠️ Reiniciar `returned` (recomendado)

Con `request = 0` ya añadido, el espacio de estados se reduce mucho. `returned` sigue guardando su último valor, y eso multiplica estados que en realidad son equivalentes. Basta con:

```promela
            loan[_pid] = 0;
            printf("C%d returns its loan %d. ...", ..., returned, ...);
            returned = 0;                      // <-- añadir, después del printf
            assert(cash + loan[0] + loan[1] + loan[2] == CAP);
```

Medidas con CAP=7 y `-DNOCLAIM`:

| Versión | Estados | Profundidad |
|---|---|---|
| Sin reiniciar nada (revisión anterior) | 2 302 832 | 756 783 |
| **Actual** (`request = 0`) | **821 160** | **155 913** (264 176 con `ltl`) |
| Con `request = 0` y `returned = 0` | 13 686 | 10 996 |

Con el código actual, el `-m` por defecto (10 000) **sigue dando `max search depth too small`**. Con `-m1000000`, el valor que sugiere el enunciado, ya es suficiente (verificado). En los comandos de este documento se usa `-m10000000` por margen.

### 4.3 Menores

- Los ficheros `pan.*`, `_spin_nvr.tmp` y `*.trail` son generados. Ejecutad en una carpeta aparte (§6) y no los incluyáis en el `.zip`.
- Opcional: `select(request : 1 .. max[_pid]-loan[_pid]);` hace lo mismo que vuestro `do` y se lee mejor.

---

## 5. Resultados obtenidos (código del commit `6320d0c`)

Como `-DCAP` no funciona todavía (§4.1), estos resultados se han obtenido generando una copia del fichero con el `#define CAP` cambiado para cada valor. Con el `#ifndef` añadido, los comandos con `-DCAP=…` dan exactamente lo mismo.

### 5.1 Objetivo 1: deadlock

Comando, una vez añadido el `#ifndef`:

```bash
spin -a -DCAP=$c bankloans.pml && gcc -w -DNOCLAIM -o pan pan.c && ./pan -m10000000
```

| CAP | ¿Deadlock? | Estados almacenados |
|---|---|---|
| 0 | sí | 10 |
| 1 | sí | 10 |
| 2 | sí | 195 |
| 3 | sí | 283 |
| 4 | sí | 1 899 |
| 5 | sí | 3 706 |
| **6** | **sí** | 3 437 |
| 7 | no | 821 160 |
| 8 | no | 830 880 |
| 9 | no | 832 500 |
| 10 | no | 832 500 |

**Resultado: x = 6.**

Con deadlock hay menos estados porque pan se detiene en el primer error que encuentra.

**Comprobación analítica.** En un deadlock, los tres clientes esperan con una petición `r_i > cash` y cumplen `loan_i + r_i <= max_i`. Por tanto `loan_i <= max_i - cash - 1`. Sumando para los tres, con `Σmax = 9` y `Σloan = CAP - cash`:

```
CAP - cash <= 9 - 3(cash + 1)   ⇒   CAP <= 6 - 2·cash
```

El máximo se alcanza con `cash = 0`, y da **CAP = 6**. Coincide con SPIN.

**Traza más corta para CAP = 6.** Se obtiene con búsqueda en anchura; el deadlock aparece a profundidad 39:

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

> Sin `-DBFS`, la traza DFS tiene unos 4 000 pasos: sirve igual, pero es ilegible. La opción `./pan -i` (acortamiento iterativo) resultó demasiado lenta.

### 5.2 Objetivo 2: safety (CAP = x+1 = 7)

```bash
spin -a -DCAP=7 bankloans.pml && gcc -w -o pan pan.c
./pan -m10000000 -N safety_cash
./pan -m10000000 -N safety_loan
```

| Propiedad | Mecanismo | Resultado |
|---|---|---|
| `0 <= cash <= CAP` | `ltl safety_cash` | ✅ `errors: 0` (821 160 estados, profundidad 264 176) |
| `0 <= loan[i] <= max[i]` | `ltl safety_loan` | ✅ `errors: 0` |
| `cash + Σloan == CAP` tras cada transferencia | `assert` en los `atomic` | ✅ Ningún assert violado en ninguna ejecución |

Además, con CAP = 7 no hay deadlock (tabla anterior).

La suma solo deja de ser `CAP` *dentro* de un `atomic`, entre la resta de `cash` y la suma de `loan`. Como el bloque es atómico, ningún otro proceso ve ese estado. Por eso el assert va al final del bloque y no se puede expresar como `[]` en LTL.

### 5.3 Objetivo 3: liveness / inanición (CAP = 7)

```bash
spin -a -DCAP=7 bankloans.pml && gcc -w -o pan pan.c
./pan -a -f -m10000000 -N liveness0    # repetir con liveness1 y liveness2
spin -DCAP=7 -t -p bankloans.pml       # muestra <<<<<START OF CYCLE>>>>>
```

| Fórmula | Resultado |
|---|---|
| `liveness0` (C0) | ❌ acceptance cycle (profundidad 856) |
| `liveness1` (C1) | ❌ acceptance cycle (profundidad 642) |
| `liveness2` (C2) | ❌ acceptance cycle (profundidad 283) |

**Contraejemplo obtenido para `liveness2` (resumido):**

```
C2 requests 3.          7:[0,0,0]     <-- C2 pide 3 € y nunca los recibirá
C1 requests 4.          7:[0,0,0]
C1 got the money 4.     3:[0,4,0]
C1 returns its loan 4.  7:[0,0,0]
...
C0 got the money 2.     1:[2,4,0]
C1 returns its loan 4.  5:[2,0,0]
C1 requests 4.          5:[2,0,0]
C1 got the money 4.     1:[2,4,0]
  <<<<<START OF CYCLE>>>>>
C1 returns its loan 4.  5:[2,0,0]
C1 requests 4.          5:[2,0,0]
C1 got the money 4.     1:[2,4,0]
C0 returns its loan 2.  3:[0,4,0]
C1 returns its loan 4.  7:[0,0,0]
C1 requests 4.          7:[0,0,0]
C1 got the money 4.     3:[0,4,0]
...                                    (se repite indefinidamente)
```

**Explicación.** C2 pide 3 € y se queda esperando. Mientras tanto, C1 y C0 piden y devuelven una y otra vez, y `cash` va cambiando entre 7, 5, 3 y 1.

En algunos momentos (`cash >= 3`) C2 podría avanzar, pero su guarda **no está habilitada de forma continua**: se desactiva cada vez que `cash` baja de 3. Weak fairness (`pan -f`, T4 p.29: `◇□enabled → □◇executed`) solo obliga a ejecutar procesos habilitados *permanentemente*. Por tanto esta ejecución infinita es justa en sentido débil y aun así C2 no cobra nunca.

La causa es que el banco no tiene cola ni prioridad: cuando hay dinero, gana el primero que se planifica. Que no haya deadlock (CAP >= 7) **no implica** que no haya inanición.

**Comprobación extra** (de la revisión anterior, mismo modelo salvo los reinicios de variables): con `CAP = 9` (= Σmax, nadie espera nunca), `liveness2` da `errors: 0`. La inanición desaparece solo cuando el capital cubre todos los máximos a la vez.

---

## 6. Guía de ejecución paso a paso

Trabajad en una carpeta aparte para no ensuciar el repositorio con `pan.*`:

```bash
mkdir -p out && cp codigo/bankloans.pml out/ && cd out
```

### 6.1 Simulación (comprobar a ojo que los `printf` tienen sentido)

```bash
spin -DCAP=7 -u300 bankloans.pml        # aleatoria, 300 pasos
spin -DCAP=7 -u300 -n42 bankloans.pml   # semilla fija, reproducible
```

### 6.2 Barrido de deadlock (objetivo 1)

**Con el `#ifndef` añadido (§4.1):**

```bash
for c in 0 1 2 3 4 5 6 7 8 9 10; do
  spin -a -DCAP=$c bankloans.pml >/dev/null
  gcc -w -DNOCLAIM -o pan pan.c
  echo "CAP=$c: $(./pan -m10000000 | grep -E 'errors:|invalid end state' | tr '\n' ' ')"
  rm -f *.trail
done
```

**Sin el `#ifndef`** (generando una copia por valor):

```bash
for c in 0 1 2 3 4 5 6 7 8 9 10; do
  sed "s/^#define CAP 10/#define CAP $c/" bankloans.pml > b.pml
  spin -a b.pml >/dev/null
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
| `invalid end states - (disabled by never claim)` | En esta ejecución no se buscan deadlocks: compilad con `-DNOCLAIM` |
| `warning: 'CAP' macro redefined` | **Vuestro `-DCAP` se ha ignorado** (§4.1) |

Las trazas se reproducen con `spin -DCAP=<mismo valor> -t -p bankloans.pml`. Usad **el mismo `-DCAP`** (o la misma copia del fichero) con el que se generó el `.trail`.

---

## 7. Checklist antes de entregar

- [x] Nombres de los alumnos en la primera línea del `.pml`
- [x] `max = {2,4,3}` y `CAP = 10` por defecto
- [x] `request = 0` tras cobrar
- [ ] `#ifndef CAP / #define CAP 10 / #endif`
- [ ] (Recomendado) `returned = 0` tras devolver
- [ ] Tabla de deadlock CAP = 0..10 con x = 6, traza BFS y su explicación
- [ ] Safety con CAP = 7: salida de pan con `errors: 0` para las dos `ltl` y los asserts
- [ ] Liveness con CAP = 7: contraejemplo con `START OF CYCLE` y su explicación (weak fairness)
- [ ] Informe en PDF o texto ASCII, con los nombres (este `.md` es solo de apoyo)
- [ ] `.zip` sin `pan.*`, `_spin_nvr.tmp` ni `*.trail`
