classdef TestUniformMps < matlab.unittest.TestCase
    % Unit tests for uniform matrix product states.
    
    properties (TestParameter)
        A = struct(...
            'trivial', {{Tensor.randnc(CartesianSpace.new([4 2]), CartesianSpace.new(4))}}, ...
            'trivial2', {{Tensor.randnc(CartesianSpace.new([4 2]), CartesianSpace.new(5)), ...
                        Tensor.randnc(CartesianSpace.new([5 2]), CartesianSpace.new(4))}}, ...
            'trivial3', {{Tensor.randnc(CartesianSpace.new([4 2]), CartesianSpace.new(5)), ...
                        Tensor.randnc(CartesianSpace.new([5 2]), CartesianSpace.new(6)), ...
                        Tensor.randnc(CartesianSpace.new([6 2]), CartesianSpace.new(4))}}, ...
            'fermion1', {{Tensor.randnc(...
                GradedSpace.new(fZ2(0,1), [2 2], false, fZ2(0,1), [1 1], false), ...
                GradedSpace.new(fZ2(0,1), [2 2], false))}}, ...
            'fermion2', {{Tensor.randnc(...
                GradedSpace.new(fZ2(0,1), [2 2], true, fZ2(0,1), [1 1], false), ...
                GradedSpace.new(fZ2(0,1), [2 2], true))}}, ...
            'fermion3', {{Tensor.randnc(...
                GradedSpace.new(fZ2(0,1), [2 2], false, fZ2(0,1), [1 1], true), ...
                GradedSpace.new(fZ2(0,1), [2 2], false))}}, ...
            'fermion4', {{Tensor.randnc(...
                GradedSpace.new(fZ2(0,1), [2 2], true, fZ2(0,1), [1 1], true), ...
                GradedSpace.new(fZ2(0,1), [2 2], true))}}, ...
            'haldane', {{Tensor.randnc(GradedSpace.new(SU2(1:2:5), [5 3 2], false, SU2(2), 1, false), ...
                                    GradedSpace.new(SU2(2:2:6), [5 2 1], false)), ...
                        Tensor.randnc(GradedSpace.new(SU2(2:2:6), [5 2 1], false, SU2(2), 1, false), ...
                                    GradedSpace.new(SU2(1:2:5), [5 3 2], false))}} ...
            )
    end
    
    methods (Test)
        function testCanonical(tc, A)
            mps = UniformMps(A);
            for i = 1:length(A)
                tc.assertTrue(...
                    isequal(space(A{i}), space(mps.AL(i)), ...
                    space(mps.AR(i)), space(mps.AC(i))));
            end
            T = transfermatrix(MpsTensor(A), mps.AL);
            [v, d] = eigsolve(transfermatrix(MpsTensor(A), mps.AL), [], 1, 'largestabs');
            [v2, d2] = eigsolve(transfermatrix(MpsTensor(A), MpsTensor(A)), [], 1, 'largestabs');
            tc.verifyTrue(isapprox(d^2, d2), 'canonical changed state?');
            
            mps = canonicalize(mps);
            AL = mps.AL; AR = mps.AR; C = mps.C; AC = mps.AC;
            tc.assertTrue(all(isisometry([mps.AL.var], 'left')), ...
                'AL should be a left isometry.');
            tc.assertTrue(all(isisometry([mps.AR.var], 'right')), ...
                'AR should be a right isometry.');
            
            for w = 1:period(mps)
                ALC = multiplyright(AL(w), C(w));
                CAR = repartition(multiplyleft(AR(w), C(prev(w, period(mps)))), rank(AC(w)));
                tc.assertTrue(isapprox(ALC, AC(w)) && isapprox(AC(w), CAR), ...
                    'AL, AR, C and AC should be properly related.');
            end
        end
        
        function testDiagonalC(tc, A)
            mps = UniformMps(A);
            mps2 = diagonalizeC(mps);
            f = fidelity(mps, mps2, 'Verbosity', Verbosity.diagnostics);
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
    end
end

