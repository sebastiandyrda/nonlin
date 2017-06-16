! nonlin_test.f90

! The testing application for the NONLIN library.
program main
    ! Imported Modules
    use nonlin_test_jacobian
    use nonlin_test_quasinewton

    ! Introduce the testing application
    print '(A)', "Hello from the NONLIN test application."

    ! Tests
    call test_jacobian_1()
end program
