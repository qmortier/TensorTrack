classdef KrylovSchur
    % KrylovSchur wrapper for Matlab implementation of eigs
    %
    % Properties
    % ----------
	% tol : :class:`double`
    %   convergence tolerance, defaults to :code:`1e-10`.
    %
	% maxiter : :class:`int`
    %   maximum number of iterations, defaults to :code:`100`.
    %
	% krylovdim : :class:`int`
    %   Krylov subspace dimension, defaults to :code:`20`.
    %
    % verbosity : :class:`.Verbosity`
    %   display information, defaults to :code:`Verbosity.warn`.
    
    properties
        tol         = 1e-10
        maxiter     = 100
        krylovdim   = 20
        verbosity   = Verbosity.warn
    end
    
    methods
        function alg = KrylovSchur(kwargs)
            arguments
                kwargs.?KrylovSchur
            end
            fields = fieldnames(kwargs);
            if ~isempty(fields)
                for field = fields.'
                    alg.(field{1}) = kwargs.(field{1});
                end
            end
        end
        
        function varargout = eigsolve(alg, A, v0, howmany, sigma, kwargs)
            % Find a few eigenvalues and eigenvectors of an operator using the builtin
            % Matlab eigs routine.
            %
            % Usage
            % -----
            % :code:`[V, D, flag] = eigsolve(A, v, howmany, sigma, kwargs)`
            %
            % :code:`D = eigsolve(A, v, ...)`
            %
            % Arguments
            % ---------
            % A : :class:`matrix` or :class:`function_handle`
            %   A square matrix.
            %   A function handle which implements one of the following, depending on sigma:
            %
            %   - :code:`A \ x`, if :code:`sigma` is 0 or 'smallestabs'
            %   - :code:(A - sigma * I) \ x`, if sigma is a nonzero scalar
            %   - :code:A * x`, for all other cases
            %
            % v : :class:`vector`
            %   initial guess for the eigenvector.
            %
            % howmany : :class:`int`
            %   amount of eigenvalues and eigenvectors that should be computed. By default
            %   this is 1, and this should not be larger than the total dimension of A.
            %
            % sigma : :class:`char` or :class:`numeric`
            %   selector for the eigenvalues, should be either one of the following:
            %
            %   - 'largestabs', 'lm': default, eigenvalues of largest magnitude
            %   - 'largestreal', 'lr': eigenvalues with largest real part
            %   - 'largestimag', 'li': eigenvalues with largest imaginary part.
            %   - 'smallestabs', 'sm': default, eigenvalues of smallest magnitude
            %   - 'smallestreal', 'sr': eigenvalues with smallest real part
            %   - 'smallestimag', 'si': eigenvalues with smallest imaginary part.
            %   - numeric : eigenvalues closest to sigma.
            %
            % Keyword Arguments
            % -----------------
            % IsSymmetric : :class:`logical`
            %   flag to speed up the algorithm if the operator is symmetric, false by
            %   default.
            %
            % Returns
            % -------
            % V : (1, howmany) :class:`vector`
            %   vector of eigenvectors.
            %
            % D : :class:`numeric`
            %   vector of eigenvalues if only a single output argument is asked, diagonal
            %   matrix of eigenvalues otherwise.
            %
            % flag : :class:`int`
            %   convergence info flag:
            %
            %   if flag = 0 then all eigenvalues are converged, otherwise not.

            arguments
                alg
                A
                v0
                howmany = 1
                sigma = 'lm'
                kwargs.IsSymmetric logical = false
            end
            
            nargoutchk(0, 3);
            
            if isnumeric(v0)
                v0_vec = v0;
                if isa(A, 'function_handle')
                    A_fun = @A;
                else
                    A_fun = @(v) A * v;
                end
            else
                v0_vec = vectorize(v0);
                if isa(A, 'function_handle')
                    A_fun = @(v) vectorize(A(devectorize(v, v0)));
                else
                    A_fun = @(v) vectorize(A * devectorize(v, v0));
                end
            end
            
            sz = size(v0_vec);
            
            if sz(1) < howmany
                howmany = sz(1);
                if alg.verbosity >= Verbosity.warn
                    warning('eigsolve:size', 'requested %d out of %d eigenvalues.', ...
                        howmany, sz(1));
                end
            end
            
            if sz(1) < alg.krylovdim
                alg.krylovdim = sz(1);
                if alg.verbosity >= Verbosity.warn
                    warning('eigsolve:size', ...
                        'Krylov subspace dimension is larger than total number of eigenvalues, reducing Krylov dimension to %d.', ...
                        sz(1));
                end
            end
            
            % call builtin eigs
            if howmany > sz(1) - 2
                % annoying bug with eigs and subspace dimension specification
                [V, D, flag] = eigs(A_fun, sz(1), howmany, sigma, ...
                    'Tolerance', alg.tol, 'MaxIterations', alg.maxiter, ...
                    'IsFunctionSymmetric', ...
                    kwargs.IsSymmetric, 'StartVector', v0_vec, ...
                    'Display', alg.verbosity >= Verbosity.iter);
            else
                [V, D, flag] = eigs(A_fun, sz(1), howmany, sigma, ...
                    'Tolerance', alg.tol, 'MaxIterations', alg.maxiter, ...
                    'SubspaceDimension', alg.krylovdim, 'IsFunctionSymmetric', ...
                    kwargs.IsSymmetric, 'StartVector', v0_vec, ...
                    'Display', alg.verbosity >= Verbosity.iter);
            end
            
            % process results
            if nargout <= 1
                varargout = {diag(D)};
            else
                if ~isnumeric(v0)
                    for i = howmany:-1:1
                        varargout{1}(:, i) = devectorize(V(:, i), v0);
                    end
                else
                    for i = howmany:-1:1
                        varargout{1}(:, i) = V(:, i);
                    end
                end
                varargout{2} = D;
                if nargout == 3
                    varargout{3} = flag;
                end
            end
            
            % display
            if nargout < 3
                if flag
                    warning('eigsolve did not converge.');
                end
            end
            if ~flag && alg.verbosity > Verbosity.warn
                fprintf('eigsolve converged.\n');
            end
        end
    end
end


