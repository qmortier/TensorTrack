classdef TestUniformMps < matlab.unittest.TestCase
    % Unit tests for uniform matrix product states.
    
    properties (TestParameter)
        A = struct(...
            'trivial', {{MpsTensor.randnc(CartesianSpace.new([4 2]), CartesianSpace.new(4))}}, ...
            'trivial2', {{MpsTensor.randnc(CartesianSpace.new([4 2]), CartesianSpace.new(5)), ...
                        MpsTensor.randnc(CartesianSpace.new([5 2]), CartesianSpace.new(4))}}, ...
            'trivial3', {{MpsTensor.randnc(CartesianSpace.new([4 2]), CartesianSpace.new(5)), ...
                        MpsTensor.randnc(CartesianSpace.new([5 2]), CartesianSpace.new(6)), ...
                        MpsTensor.randnc(CartesianSpace.new([6 2]), CartesianSpace.new(4))}}, ...
            'fermion1', {{MpsTensor.randnc(...
                GradedSpace.new(fZ2(0,1), [2 2], false, fZ2(0,1), [1 1], false), ...
                GradedSpace.new(fZ2(0,1), [2 2], false))}}, ...
            'fermion2', {{MpsTensor.randnc(...
                GradedSpace.new(fZ2(0,1), [2 2], true, fZ2(0,1), [1 1], false), ...
                GradedSpace.new(fZ2(0,1), [2 2], true))}}, ...
            'fermion3', {{MpsTensor.randnc(...
                GradedSpace.new(fZ2(0,1), [2 2], false, fZ2(0,1), [1 1], true), ...
                GradedSpace.new(fZ2(0,1), [2 2], false))}}, ...
            'fermion4', {{MpsTensor.randnc(...
                GradedSpace.new(fZ2(0,1), [2 2], true, fZ2(0,1), [1 1], true), ...
                GradedSpace.new(fZ2(0,1), [2 2], true))}}, ...
            'haldane', {{MpsTensor.randnc(GradedSpace.new(SU2(1:2:5), [5 3 2], false, SU2(2), 1, false), ...
                                    GradedSpace.new(SU2(2:2:6), [5 2 1], false)), ...
                        MpsTensor.randnc(GradedSpace.new(SU2(2:2:6), [5 2 1], false, SU2(2), 1, false), ...
                                    GradedSpace.new(SU2(1:2:5), [5 3 2], false))}} ...
            )
    end
    
    methods (Test)
        function testCanonical(tc, A)
            mps = UniformMps(A);
            
            for i = 1:length(A)
                tc.assertTrue(...
                    isequal(space(A{i}), space(mps.AL{i}), ...
                    space(mps.AR{i}), space(mps.AC{i})));
            end
            
            T = cellfun(@transfermatrix, A, mps.AL);
            [v, d] = eigsolve(T, [], 1, 'largestabs');
            T2 = cellfun(@transfermatrix, A, A);
            [v2, d2] = eigsolve(T2, [], 1, 'largestabs');
            tc.verifyTrue(isapprox(d^2, d2), 'canonical changed state?');
            
            mps = canonicalize(mps);
            AL = mps.AL; AR = mps.AR; C = mps.C; AC = mps.AC;
            tc.assertTrue(all(cellfun(@(x) isisometry(x, 'left'), AL)), ...
                'AL should be a left isometry.');
            tc.assertTrue(all(cellfun(@(x) isisometry(x, 'right'), AR)), ...
                'AR should be a right isometry.');
            
            for w = 1:period(mps)
                ALC = multiplyright(AL{w}, C{w});
                CAR = repartition(multiplyleft(AR{w}, C{prev(w, period(mps))}), rank(AC{w}));
                tc.assertTrue(isapprox(ALC, AC{w}) && isapprox(AC{w}, CAR), ...
                    'AL, AR, C and AC should be properly related.');
            end
        end
        
        function testDiagonalC(tc, A)
            mps = UniformMps(A);
            mps2 = diagonalizeC(mps);
            f = fidelity(mps, mps2);
            tc.assertTrue(isapprox(f, 1), 'Diagonalizing C should not alter the state.');
        end
        
        function testFixedpoints(tc, A)
            mps = UniformMps(A);
            for top = ["L" "R"]
                for bot = ["L" "R"]
                    T = transfermatrix(mps, mps, 'Type', sprintf('%c%c', top, bot));
                    rhoL = fixedpoint(mps, sprintf('l_%c%c', top, bot));
                    rhoR = fixedpoint(mps, sprintf('r_%c%c', top, bot));
                    tc.verifyTrue(isapprox(rhoL, T.apply(rhoL)), ...
                        sprintf('rho_left should be a %c%c fixed point.', top, bot));
                    tc.verifyTrue(isapprox(rhoR, apply(T', rhoR)), ...
                        sprintf('rho_right should be a %c%c fixed point.', top, bot));
                end
            end
        end
        
        function testTransferEigs(tc, A)
           mps = UniformMps(A);
           
           [V, D] = transfereigs(mps, mps, 1, 'largestabs');
           [~, charges] = matrixblocks(V);
           [V2, D2] = transfereigs(mps, mps, 1, 'largestabs', 'Charge', one(charges));
           
           xi = correlation_length(mps);
           [epsilon, delta] = marek_gap(mps);
           tc.verifyEqual(xi, 1/epsilon, 'AbsTol', 1e-12);
        end
    end
end

