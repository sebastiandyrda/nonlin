# nonlin
A library that provides routines to compute the solutions to systems of nonlinear equations.

## Example 1
This example solves a set of two equations of two unknowns using a Quasi-Newton type solver.  In this example, the solver is left to compute the derivatives numerically.

```fortran
program example
    use linalg_constants, only : dp, i32
    use nonlin_types, only : vecfcn_helper, vecfcn
    use nonlin_solve, only : quasi_newton_solver
    implicit none

    ! Local Variables
    type(vecfcn_helper) :: obj
    procedure(vecfcn), pointer :: fcn
    type(quasi_newton_solver) :: solver
    real(dp) :: x(2), f(2)

    ! Locate the routine containing the equations to solve
    fcn => fcns
    call obj%set_fcn(fcn, 2, 2)

    ! Define an initial guess
    x = 1.0d0 ! Equivalent to x = [1.0d0, 1.0d0]

    ! Solve
    call solver%solve(obj, x, f)

    ! Display the output
    print "(AF9.5AF9.5A)", "Solution: (", x(1), ", ", x(2), ")"
    print "(AE9.3AE9.3A)", "Residual: (", f(1), ", ", f(2), ")"

contains
    ! Define the routine containing the equations to solve.  The equations are:
    ! x**2 + y**2 = 34
    ! x**2 - 2 * y**2 = 7
    subroutine fcns(x, f)
        real(dp), intent(in), dimension(:) :: x
        real(dp), intent(out), dimension(:) :: f
        f(1) = x(1)**2 + x(2)**2 - 34.0d0
        f(2) = x(1)**2 - 2.0d0 * x(2)**2 - 7.0d0
    end subroutine
end program
```
The example yields the solution vector: x = [5.0, 3.0], with a maximum residual of 0.121e-9.  The solution converged in a total of 10 iterations, with 2 Jacobian evaluations, and 14 additional function evaluations.

## Example 2
This example uses a least-squares approach to determine the coefficients of a polynomial that best fits a set of data.

```fortran
program example
    use linalg_constants, only : dp, i32
    use nonlin_types, only : vecfcn_helper, vecfcn
    use nonlin_least_squares, only : least_squares_solver
    implicit none

    ! Local Variables
    type(vecfcn_helper) :: obj
    procedure(vecfcn), pointer :: fcn
    type(least_squares_solver) :: solver
    real(dp) :: x(4), f(21) ! There are 4 coefficients and 21 data points

    ! Locate the routine containing the equations to solve
    fcn => fcns
    call obj%set_fcn(fcn, 21, 4)

    ! Define an initial guess
    x = 1.0d0 ! Equivalent to x = [1.0d0, 1.0d0, 1.0d0, 1.0d0]

    ! Solve
    call solver%solve(obj, x, f)

    ! Display the output
    print "(AF12.8)", "c1: ", x(1)
    print "(AF12.8)", "c2: ", x(2)
    print "(AF12.8)", "c3: ", x(3)
    print "(AF12.8)", "c4: ", x(4)
    print "(AF9.5)", "Max Residual: ", maxval(abs(f))

contains
    ! The function containing the data to fit
    subroutine fcns(x, f)
        ! Arguments
        real(dp), intent(in), dimension(:) :: x  ! Contains the coefficients
        real(dp), intent(out), dimension(:) :: f

        ! Local Variables
        real(dp), dimension(21) :: xp, yp

        ! Data to fit (21 data points)
        xp = [0.0d0, 0.1d0, 0.2d0, 0.3d0, 0.4d0, 0.5d0, 0.6d0, 0.7d0, 0.8d0, &
            0.9d0, 1.0d0, 1.1d0, 1.2d0, 1.3d0, 1.4d0, 1.5d0, 1.6d0, 1.7d0, &
            1.8d0, 1.9d0, 2.0d0]
        yp = [1.216737514d0, 1.250032542d0, 1.305579195d0, 1.040182335d0, &
            1.751867738d0, 1.109716707d0, 2.018141531d0, 1.992418729d0, &
            1.807916923d0, 2.078806005d0, 2.698801324d0, 2.644662712d0, &
            3.412756702d0, 4.406137221d0, 4.567156645d0, 4.999550779d0, &
            5.652854194d0, 6.784320119d0, 8.307936836d0, 8.395126494d0, &
            10.30252404d0]

        ! We'll apply a cubic polynomial model to this data:
        ! y = c1 * x**3 + c2 * x**2 + c3 * x + c4
        f = x(1) * xp**3 + x(2) * xp**2 + x(3) * xp + x(4) - yp

        ! For reference, the data was generated by adding random errors to
        ! the following polynomial: y = x**3 - 0.3 * x**2 + 1.2 * x + 0.3
    end subroutine
end program
```
The example yields the following coefficients:
- c1: 1.064762757
- c2: -0.122320291
- c3: 0.446613446
- c4: 1.186614224

These coefficients yield a maximum residual of 0.5064.

The following graph illustrates the fit.
![](images/Curve_Fit_Example_1.png?raw=true)

## C Example 1
This example illustrates the C equivalent to Example 1 from above.
```c
#include <stdio.h>
#include <stdlib.h>
#include "include/nonlin.h"

void testfcn(int neqn, int nvar, const double *x, double *f);

int main() {
    // Local Variables
    solver_control tol;
    line_search_control ls;
    iteration_behavior ib;
    double x[2], f[2];

    // Initialization
    tol.max_evals = 500;
    tol.fcn_tolerance = 1.0e-8;
    tol.var_tolerances = 1.0e-12;
    tol.grad_tolerances = 1.0e-12;
    tol.print_status = true;
    ls.max_evals = 100;
    ls.alpha = 1.0e-4;
    ls.factor = 0.1;
    x[0] = 1.0;
    x[1] = 1.0;

    // Compute the solution using a Quasi-Newton method
    solve_quasi_newton(testfcn, NULL, 2, x, f, &tol, &ls, &ib, NULL);

    // Display the results
    printf("\nRESULTS:\nX = (%f, %f)\nF = (%e, %e)\n", x[0], x[1], f[0], f[1]);
    printf("Iterations: %i\nFunction Evaluations: %i\nJacobian Evaluations: %i\n",
           ib.iter_count, ib.fcn_count, ib.jacobian_count);

    // End
    return 0;
}


void testfcn(int neqn, int nvar, const double *x, double *f) {
    f[0] = x[0] * x[0] + x[1] * x[1] - 34.0;
    f[1] = x[0] * x[0] - 2.0 * x[1] * x[1] - 7.0;
}
```
The output of the above is as follows:
```text
Iteration: 1
Function Evaluations: 3
Jacobian Evaluations: 1
Change in Variable: .545E+00
Residual: .272E+02

Iteration: 2
Function Evaluations: 5
Jacobian Evaluations: 1
Change in Variable: .327E+00
Residual: .196E+02

Iteration: 3
Function Evaluations: 6
Jacobian Evaluations: 1
Change in Variable: .473E+00
Residual: .128E+02

Iteration: 4
Function Evaluations: 7
Jacobian Evaluations: 1
Change in Variable: .378E+00
Residual: .377E+01

Iteration: 5
Function Evaluations: 9
Jacobian Evaluations: 1
Change in Variable: .768E-01
Residual: .157E+01

Iteration: 6
Function Evaluations: 10
Jacobian Evaluations: 1
Change in Variable: .253E-01
Residual: .689E+00

Iteration: 7
Function Evaluations: 11
Jacobian Evaluations: 2
Change in Variable: .136E-01
Residual: .288E-02

Iteration: 8
Function Evaluations: 12
Jacobian Evaluations: 2
Change in Variable: .927E-04
Residual: .324E-04

Iteration: 9
Function Evaluations: 13
Jacobian Evaluations: 2
Change in Variable: .791E-06
Residual: .406E-07

RESULTS:
X = (5.000000, 3.000000)
F = (6.038903e-011, 1.206786e-010)
Iterations: 10
Function Evaluations: 14
Jacobian Evaluations: 2
```

## C Example 2
This example is the same as example 1, but uses Newton's method without any line-search.
```c
#include <stdio.h>
#include <stdlib.h>
#include "include/nonlin.h"

void testfcn(int neqn, int nvar, const double *x, double *f);

int main() {
    // Local Variables
    solver_control tol;
    iteration_behavior ib;
    double x[2], f[2];

    // Initialization
    tol.max_evals = 500;
    tol.fcn_tolerance = 1.0e-8;
    tol.var_tolerances = 1.0e-12;
    tol.grad_tolerances = 1.0e-12;
    tol.print_status = true;
    x[0] = 1.0;
    x[1] = 1.0;

    // Compute the solution using Newton's method
    solve_newton(testfcn, NULL, 2, x, f, &tol, NULL, &ib, NULL);

    // Display the results
    printf("\nRESULTS:\nX = (%f, %f)\nF = (%e, %e)\n", x[0], x[1], f[0], f[1]);
    printf("Iterations: %i\nFunction Evaluations: %i\nJacobian Evaluations: %i\n",
           ib.iter_count, ib.fcn_count, ib.jacobian_count);

    // End
    return 0;
}


void testfcn(int neqn, int nvar, const double *x, double *f) {
    f[0] = x[0] * x[0] + x[1] * x[1] - 34.0;
    f[1] = x[0] * x[0] - 2.0 * x[1] * x[1] - 7.0;
}
```
The output of the above is as follows:
```text
Iteration: 1
Function Evaluations: 2
Jacobian Evaluations: 1
Change in Variable: 0.923E+00
Residual: 0.160E+03

Iteration: 2
Function Evaluations: 3
Jacobian Evaluations: 2
Change in Variable: 0.742E+00
Residual: 0.332E+02

Iteration: 3
Function Evaluations: 4
Jacobian Evaluations: 3
Change in Variable: 0.380E+00
Residual: 0.437E+01

Iteration: 4
Function Evaluations: 5
Jacobian Evaluations: 4
Change in Variable: 0.779E-01
Residual: 0.153E+00

Iteration: 5
Function Evaluations: 6
Jacobian Evaluations: 5
Change in Variable: 0.304E-02
Residual: 0.232E-03

RESULTS:
X = (5.000000, 3.000000)
F = (5.390746e-010, 5.390710e-010)
Iterations: 6
Function Evaluations: 7
Jacobian Evaluations: 6
```
## Documentation
Documentation can be found [here](doc/refman.pdf)
