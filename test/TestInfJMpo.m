classdef TestInfJMpo < matlab.unittest.TestCase
    % Unit tests for infinite matrix product operators.
    
    properties (TestParameter)
        mpo = struct(...
            'trivial', quantum1dIsing() ...
            )
        mps = struct(...
            'trivial', UniformMps.randnc(CartesianSpace.new(2), CartesianSpace.new(4)) ...
            )
    end
    
    methods (Test, ParameterCombination='sequential')
        function testEnvironments(tc, mpo, mps)
            [GL, lambdaL] = leftenvironment(mpo, mps, mps);
            tc.verifyTrue(isapprox(abs(lambdaL), abs(real(lambdaL)), 'RelTol', 1e-6), ...
                sprintf('lambda should be real. (%-g i)', imag(lambdaL)));
            
            [GR, lambdaR] = rightenvironment(mpo, mps, mps);
            tc.verifyTrue(isapprox(abs(lambdaR), abs(real(lambdaR)), 'RelTol', 1e-6), ...
                sprintf('lambda should be real. (%gi)', imag(lambdaR)));
            
            tc.verifyTrue(isapprox(lambdaL, lambdaR), 'lambdas should be equal.');
        end
        
        function testDerivatives(tc, mpo, mps)
            [GL, GR] = environments(mpo, mps, mps);
            
            H_AC = AC_hamiltonian(mpo, mps, GL, GR);
            for i = 1:numel(H_AC)
                AC_ = mps.AC(i);
                [AC_.var, lambda] = eigsolve(H_AC{i}, mps.AC(i).var, 1, 'largestabs');
                tc.assertTrue(isapprox(apply(H_AC{i}, AC_), lambda * AC_.var));
            end
            
            H_C = C_hamiltonian(mpo, mps, GL, GR);
            for i = 1:numel(H_C)
                [C_, lambda] = eigsolve(H_C{i}, mps.C(i), 1, 'largestabs');
                tc.assertTrue(isapprox(apply(H_C{i}, C_), lambda * C_));
            end
        end
        
        function test1dIsing(tc)            
            alg = Vumps('which', 'smallestreal', 'maxiter', 5);
            D = 16;
            mpo = quantum1dIsing('J', 1, 'h', 1, 'L', Inf);
            mps = initialize_mps(mpo, CartesianSpace.new(D));
            [mps2, lambda] = fixedpoint(alg, mpo, mps);
            tc.verifyTrue(isapprox(lambda, -1.27, 'RelTol', 1e-2))
            
            mpo = quantum1dIsing('J', 1, 'h', 1, 'L', Inf, 'Symmetry', 'Z2');
            mps = initialize_mps(mpo, GradedSpace.new(Z2(0, 1), [D D] ./ 2, false));
            [mps2, lambda2] = fixedpoint(alg, mpo, mps);
            tc.verifyTrue(isapprox(lambda, -1.27, 'RelTol', 1e-2))
            
            mpo = [mpo mpo];
            mps = [mps mps];
            [mps2, lambda2] = fixedpoint(alg, mpo, mps);
            tc.verifyTrue(isapprox(lambda2/2, -1.27, 'RelTol', 5e-2))
        end
        
        function test1dHeisenberg(tc)
            alg = Vumps('which', 'smallestreal', 'maxiter', 5);
            
            mpo = quantum1dHeisenberg('Spin', 1, 'Symmetry', 'SU2');
            mpo = [mpo mpo];
            
            vspace1 = GradedSpace.new(SU2(1:2:5), [5 5 1], false);
            vspace2 = GradedSpace.new(SU2(1:2:5), [5 5 1], false);
            mps = initialize_mps(mpo, vspace1, vspace2);
            
            [gs_mps] = fixedpoint(alg, mpo, mps);
            lambda = expectation_value(gs_mps, mpo);
            tc.verifyEqual(lambda / period(mps), -1.40, 'RelTol', 1e-2);
            
        end
    end
end

