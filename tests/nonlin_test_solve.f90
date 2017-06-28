! nonlin_test_solve.f90

module nonlin_test_solve
    use linalg_constants, only : dp, i32
    use nonlin_types
    use nonlin_solve
    use nonlin_least_squares
    use ferror, only : errors
    implicit none
    private
    public :: test_quasinewton_1
    public :: test_quasinewton_2
    public :: test_newton_1
    public :: test_newton_2
    public :: test_least_squares_1
    public :: test_least_squares_2
    public :: test_least_squares_3
    public :: test_brent_1
contains
! ******************************************************************************
! TEST FUNCTIONS
! ------------------------------------------------------------------------------
    ! System of Equations #1:
    !
    ! x**2 + y**2 = 34
    ! x**2 - 2 * y**2 = 7
    !
    ! Solution:
    ! x = +/-5
    ! y = +/-3
    subroutine fcn1(x, f)
        real(dp), intent(in), dimension(:) :: x
        real(dp), intent(out), dimension(:) :: f
        f(1) = x(1)**2 + x(2)**2 - 34.0d0
        f(2) = x(1)**2 - 2.0d0 * x(2)**2 - 7.0d0
    end subroutine

    ! Jacobian:
    !
    !     | 2x  2y |
    ! J = |        |
    !     | 2x  -4y|
    subroutine jac1(x, j)
        real(dp), intent(in), dimension(:) :: x
        real(dp), intent(out), dimension(:,:) :: j
        j = 2.0d0 * reshape([x(1), x(1), x(2), -2.0d0 * x(2)], [2, 2])
    end subroutine

    pure function is_ans_1(x, tol) result(c)
        real(dp), intent(in), dimension(:) :: x
        real(dp), intent(in) :: tol
        logical :: c
        real(dp), parameter :: x1 = 5.0d0
        real(dp), parameter :: x2 = 3.0d0
        real(dp) :: ax1, ax2
        c = .true.
        ax1 = abs(x(1)) - x1
        ax2 = abs(x(2)) - x2
        if (abs(ax1) > tol .or. abs(ax2) > tol) c = .false.
    end function

! ------------------------------------------------------------------------------
    ! System of Equations #2 (Poorly Scaled Problem)
    ! REF: http://folk.uib.no/ssu029/Pdf_file/Hiebert82.pdf
    !
    ! x2 - 10 = 0
    ! x1 * x2 - 5e4 = 0
    !
    ! Solution:
    ! x1 = 5e3
    ! x2 = 10
    subroutine fcn2(x, f)
        real(dp), intent(in), dimension(:) :: x
        real(dp), intent(out), dimension(:) :: f
        f(1) = x(2) - 10.0d0
        f(2) = x(1) * x(2) - 5e4
    end subroutine

    pure function is_ans_2(x, tol) result(c)
        real(dp), intent(in), dimension(:) :: x
        real(dp), intent(in) :: tol
        real(dp) :: ax1, ax2
        logical :: c
        real(dp), parameter :: x1 = 5.0d3
        real(dp), parameter :: x2 = 1.0d1
        c = .true.
        ax1 = abs(x(1)) - x1
        ax2 = abs(x(2)) - x2
        if (abs(ax1) > tol .or. abs(ax2) > tol) c = .false.
    end function

! ******************************************************************************
! LEAST SQUARES FUNCTIONS
! ------------------------------------------------------------------------------
    subroutine lsfcn1(x, f)
        ! Arguments
        real(dp), intent(in), dimension(:) :: x
        real(dp), intent(out), dimension(:) :: f

        ! Local Variables
        real(dp), dimension(21) :: xp, yp

        ! Data to fit
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

! ******************************************************************************
! 1 VARIABLE FUNCTIONS
! ------------------------------------------------------------------------------
    ! f(x) = sin(x) / x, SOLUTION: x = n * pi for n = 0, 1, 2, 3, ...
    function f1var_1(x) result(f)
        real(dp), intent(in) :: x
        real(dp) :: f
        f = sin(x) / x
    end function

! ******************************************************************************
! SOLVER TEST ROUTINES
! ------------------------------------------------------------------------------
    subroutine test_quasinewton_1()
        ! Local Variables
        type(vecfcn_helper) :: obj
        procedure(vecfcn), pointer :: fcn
        procedure(jacobianfcn), pointer :: jac
        type(quasi_newton_solver) :: solver
        type(iteration_behavior) :: ib
        real(dp) :: x(2), f(2), ic(10, 2)
        integer(i32) :: i
        logical :: check

        ! Initialization
        check = .true.
        fcn => fcn1
        jac => jac1
        call obj%set_fcn(fcn, 2, 2)
        call obj%set_jacobian(jac)

        ! Generate a set of initial conditions
        call random_number(ic)
        ic = 10.0d0 * ic

        ! Process - Cycle over each different initial condition set
        do i = 1, size(ic, 1)
            x = ic(i,:)
            call solver%solve(obj, x, f, ib)
            if (.not.is_ans_1(x, 1.0d-6)) then
                check = .false.
                print '(AI0)', "Quasi-Newton Solver Failed: Test 1-", i
                print '(AF9.5AF9.5)', "Initial Condition: ", ic(i,1), ", ", &
                    ic(i,2)
                print '(AF9.5AF9.5)', "Solution:", x(1), ", ", x(2)
                print '(AF9.5AF9.5)', "Residual:", f(1), ", ", f(2)
                print '(AL)', "Converged on residual: ", ib%converge_on_fcn
                print '(AL)', "Converged on solution change: ", &
                    ib%converge_on_chng
                print '(AL)', "Converge on zero gradient: ", &
                    ib%converge_on_zero_diff
                print '(AI0)', "Iterations: ", ib%iter_count
                print '(AI0)', "Function Evaluations: ", ib%fcn_count
            end if
        end do

        ! Inform user of a succussful test
        if (check) then
            print '(A)', "Test Passed: Quasi-Newton Test 1"
        end if
    end subroutine

! ------------------------------------------------------------------------------
    subroutine test_quasinewton_2()
        ! Local Variables
        type(vecfcn_helper) :: obj
        procedure(vecfcn), pointer :: fcn
        type(quasi_newton_solver) :: solver
        type(iteration_behavior) :: ib
        real(dp) :: x(2), f(2), ic(10, 2)
        integer(i32) :: i
        logical :: check

        ! Initialization
        check = .true.
        fcn => fcn2
        call obj%set_fcn(fcn, 2, 2)

        ! Generate a set of initial conditions
        call random_number(ic)

        ! Turn off the line search - this set of functions is too poorly scaled
        ! for the current implementation of the line search algorithm to offer
        ! much help.  This seems to indicate a need for improvement in the 
        ! line search code - perhaps variable scaling?
        call solver%set_use_line_search(.false.)

        ! Process - Cycle over each different initial condition set
        do i = 1, size(ic, 1)
            x = ic(i,:)
            call solver%solve(obj, x, f, ib)
            if (.not.is_ans_2(x, 1.0d-6)) then
                check = .false.
                print '(AI0)', "Quasi-Newton Solver Failed: Test 2-", i
                print '(AF9.5AF9.5)', "Initial Condition: ", ic(i,1), ", ", &
                    ic(i,2)
                print '(AF9.5AF9.5)', "Solution:", x(1), ", ", x(2)
                print '(AF9.5AF9.5)', "Residual:", f(1), ", ", f(2)
                print '(AL)', "Converged on residual: ", ib%converge_on_fcn
                print '(AL)', "Converged on solution change: ", &
                    ib%converge_on_chng
                print '(AL)', "Converge on zero gradient: ", &
                    ib%converge_on_zero_diff
                print '(AI0)', "Iterations: ", ib%iter_count
                print '(AI0)', "Function Evaluations: ", ib%fcn_count
            end if
        end do

        ! Inform user of a succussful test
        if (check) then
            print '(A)', "Test Passed: Quasi-Newton Test 2"
        end if
    end subroutine

! ------------------------------------------------------------------------------
    subroutine test_newton_1()
        ! Local Variables
        type(vecfcn_helper) :: obj
        procedure(vecfcn), pointer :: fcn
        procedure(jacobianfcn), pointer :: jac
        type(newton_solver) :: solver
        type(iteration_behavior) :: ib
        real(dp) :: x(2), f(2), ic(10, 2)
        integer(i32) :: i
        logical :: check

        ! Initialization
        check = .true.
        fcn => fcn1
        jac => jac1
        call obj%set_fcn(fcn, 2, 2)
        call obj%set_jacobian(jac)

        ! Generate a set of initial conditions
        call random_number(ic)
        ic = 10.0d0 * ic

        ! Process - Cycle over each different initial condition set
        do i = 1, size(ic, 1)
            x = ic(i,:)
            call solver%solve(obj, x, f, ib)
            if (.not.is_ans_1(x, 1.0d-6)) then
                check = .false.
                print '(AI0)', "Newton Solver Failed: Test 1-", i
                print '(AF9.5AF9.5)', "Initial Condition: ", ic(i,1), ", ", &
                    ic(i,2)
                print '(AF9.5AF9.5)', "Solution:", x(1), ", ", x(2)
                print '(AF9.5AF9.5)', "Residual:", f(1), ", ", f(2)
                print '(AL)', "Converged on residual: ", ib%converge_on_fcn
                print '(AL)', "Converged on solution change: ", &
                    ib%converge_on_chng
                print '(AL)', "Converge on zero gradient: ", &
                    ib%converge_on_zero_diff
                print '(AI0)', "Iterations: ", ib%iter_count
                print '(AI0)', "Function Evaluations: ", ib%fcn_count
            end if
        end do

        ! Inform user of a succussful test
        if (check) then
            print '(A)', "Test Passed: Newton Test 1"
        end if
    end subroutine

! ------------------------------------------------------------------------------
    subroutine test_newton_2()
        ! Local Variables
        type(vecfcn_helper) :: obj
        procedure(vecfcn), pointer :: fcn
        type(newton_solver) :: solver
        type(iteration_behavior) :: ib
        real(dp) :: x(2), f(2), ic(10, 2)
        integer(i32) :: i
        logical :: check

        ! Initialization
        check = .true.
        fcn => fcn2
        call obj%set_fcn(fcn, 2, 2)

        ! Generate a set of initial conditions
        call random_number(ic)

        ! Turn off the line search - this set of functions is too poorly scaled
        ! for the current implementation of the line search algorithm to offer
        ! much help.  This seems to indicate a need for improvement in the 
        ! line search code - perhaps variable scaling?
        call solver%set_use_line_search(.false.)

        ! Process - Cycle over each different initial condition set
        do i = 1, size(ic, 1)
            x = ic(i,:)
            call solver%solve(obj, x, f, ib)
            if (.not.is_ans_2(x, 1.0d-6)) then
                check = .false.
                print '(AI0)', "Newton Solver Failed: Test 2-", i
                print '(AF9.5AF9.5)', "Initial Condition: ", ic(i,1), ", ", &
                    ic(i,2)
                print '(AF9.5AF9.5)', "Solution:", x(1), ", ", x(2)
                print '(AF9.5AF9.5)', "Residual:", f(1), ", ", f(2)
                print '(AL)', "Converged on residual: ", ib%converge_on_fcn
                print '(AL)', "Converged on solution change: ", &
                    ib%converge_on_chng
                print '(AL)', "Converge on zero gradient: ", &
                    ib%converge_on_zero_diff
                print '(AI0)', "Iterations: ", ib%iter_count
                print '(AI0)', "Function Evaluations: ", ib%fcn_count
            end if
        end do

        ! Inform user of a succussful test
        if (check) then
            print '(A)', "Test Passed: Newton Test 2"
        end if
    end subroutine

! ------------------------------------------------------------------------------
    subroutine test_least_squares_1()
        ! Local Variables
        type(vecfcn_helper) :: obj
        procedure(vecfcn), pointer :: fcn
        procedure(jacobianfcn), pointer :: jac
        type(least_squares_solver) :: solver
        type(iteration_behavior) :: ib
        real(dp) :: x(2), f(2), ic(10, 2)
        integer(i32) :: i
        logical :: check

        ! Initialization
        check = .true.
        fcn => fcn1
        jac => jac1
        call obj%set_fcn(fcn, 2, 2)
        call obj%set_jacobian(jac)

        ! Generate a set of initial conditions
        call random_number(ic)
        ic = 10.0d0 * ic

        ! Process - Cycle over each different initial condition set
        do i = 1, size(ic, 1)
            x = ic(i,:)
            call solver%solve(obj, x, f, ib)
            if (.not.is_ans_1(x, 1.0d-6)) then
                check = .false.
                print '(AI0)', "Least Squares Solver Failed: Test 1-", i
                print '(AF9.5AF9.5)', "Initial Condition: ", ic(i,1), ", ", &
                    ic(i,2)
                print '(AF9.5AF9.5)', "Solution:", x(1), ", ", x(2)
                print '(AF9.5AF9.5)', "Residual:", f(1), ", ", f(2)
                print '(AL)', "Converged on residual: ", ib%converge_on_fcn
                print '(AL)', "Converged on solution change: ", &
                    ib%converge_on_chng
                print '(AL)', "Converge on zero gradient: ", &
                    ib%converge_on_zero_diff
                print '(AI0)', "Iterations: ", ib%iter_count
                print '(AI0)', "Function Evaluations: ", ib%fcn_count
            end if
        end do

        ! Inform user of a succussful test
        if (check) then
            print '(A)', "Test Passed: Least Squares Test 1"
        end if
    end subroutine

! ------------------------------------------------------------------------------
    subroutine test_least_squares_2()
        ! Local Variables
        type(vecfcn_helper) :: obj
        procedure(vecfcn), pointer :: fcn
        type(least_squares_solver) :: solver
        type(iteration_behavior) :: ib
        real(dp) :: x(2), f(2), ic(10, 2)
        integer(i32) :: i
        logical :: check
        type(errors) :: errmgr

        ! Initialization
        check = .true.
        fcn => fcn2
        call obj%set_fcn(fcn, 2, 2)

        ! Do not terminate testing if the solution does not converge.  This
        ! routine may have a bit of issue with this problem.  It can take
        ! many iterations to converge.
        call errmgr%set_exit_on_error(.false.)

        ! Increase the number of iterations allowed
        call solver%set_max_fcn_evals(1000)

        ! Generate a set of initial conditions
        call random_number(ic)

        ! Process - Cycle over each different initial condition set
        do i = 1, size(ic, 1)
            x = ic(i,:)
            call solver%solve(obj, x, f, ib, err = errmgr)
            if (.not.is_ans_2(x, 1.0d-6)) then
                check = .false.
                print '(AI0)', "Least Squares Solver Failed: Test 2-", i
                print '(AF9.5AF9.5)', "Initial Condition: ", ic(i,1), ", ", &
                    ic(i,2)
                print '(AF9.5AF9.5)', "Solution:", x(1), ", ", x(2)
                print '(AF9.5AF9.5)', "Residual:", f(1), ", ", f(2)
                print '(AL)', "Converged on residual: ", ib%converge_on_fcn
                print '(AL)', "Converged on solution change: ", &
                    ib%converge_on_chng
                print '(AL)', "Converge on zero gradient: ", &
                    ib%converge_on_zero_diff
                print '(AI0)', "Iterations: ", ib%iter_count
                print '(AI0)', "Function Evaluations: ", ib%fcn_count
            end if
        end do

        ! Inform user of a succussful test
        if (check) then
            print '(A)', "Test Passed: Least Squares Test 2"
        end if
    end subroutine

! ------------------------------------------------------------------------------
    subroutine test_least_squares_3()
        ! Local Variables
        type(vecfcn_helper) :: obj
        procedure(vecfcn), pointer :: fcn
        type(least_squares_solver) :: solver
        real(dp) :: x(4), f(21) ! There are 4 coefficients and 21 data points

        ! Initialization
        fcn => lsfcn1
        x = 1.0d0   ! Set X to an initial guess of [1, 1, 1, 1]
        call obj%set_fcn(fcn, 21, 4)

        ! Compute the solution, and store the polynomial coefficients in X
        call solver%solve(obj, x, f)

        ! Print out the coefficients
        !print *, x
    end subroutine

! ------------------------------------------------------------------------------
    subroutine test_brent_1()
        ! Local Variables
        type(brent_solver) :: solver
        type(fcn1var_helper) :: obj
        procedure(fcn1var), pointer :: fcn
        real(dp) :: x, f
        type(value_pair) :: limits
        logical :: check

        ! Parameters
        real(dp), parameter :: pi = 3.141592653589793d0
        real(dp), parameter :: tol = 1.0d-8

        ! Initialization
        check = .true.
        fcn => f1var_1
        call obj%set_fcn(fcn)

        ! Define the search limits
        limits%x1 = 1.5d0
        limits%x2 = 5.0d0

        ! Compute the solution
        call solver%solve(obj, x, limits, f)

        ! The solution on this interval should be: pi
        if (abs(x - pi) > tol) then
            check = .false.
            print '(AF8.5AF8.5)', &
                "Test Failed: Brent's Method Test 1.  Expected: ", pi, &
                ", Found: ", x
        end if

        ! Check
        if (check) then
            print '(A)', "Test Passed: Brent's Method Test 1"
        end if
    end subroutine

! ------------------------------------------------------------------------------
end module
