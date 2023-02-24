classdef UniformMps
    % UniformMps - Implementation of infinite translation invariant MPS
    %
    % The center gauge is defined to have:
    %   :math:`AL_w * C_w = AC_w = C_{w-1} * AR_w`
    %
    % Properties
    % ----------
    % AL : :class:`MpsTensor`
    %   left-gauged mps tensors.
    %
    % AR : :class:`MpsTensor`
    %   right-gauged mps tensors.
    %
    % C : :class:`Tensor`
    %   center gauge transform.
    %
    % AC : :class:`MpsTensor`
    %   center-gauged mps tensors.
    
    properties
        AL (1,:) MpsTensor
        AR (1,:) MpsTensor
        C  (1,:) Tensor
        AC (1,:) MpsTensor
    end
    
    
    %% Constructors
    methods
        function mps = UniformMps(varargin)
            % Usage
            % -----
            % :code:`mps = UniformMps(A)`
            %
            % :code:`mps = UniformMps(AL, AR, C [, AC])`
            %
            % Arguments
            % ---------
            % A : :class:`MpsTensor` or :class:`PeriodicCell`
            %   set of tensors per site that define an MPS to be gauged.
            %
            % AL, AR, AC : :class:`MpsTensor` or :class:`PeriodicCell`
            %   set of gauged MpsTensors.
            %
            % C : :class:`Tensor`
            %   gauge tensor.
            %
            % Returns
            % -------
            % mps : :class:`UniformMps`
            %   gauged uniform MPS.
            
            if nargin == 0, return; end % default empty constructor
            
            if nargin == 1
                if isa(varargin{1}, 'UniformMps') % copy constructor
                    for i = numel(varargin{1}):-1:1
                        mps(i).AL = varargin{1}(i).AL;
                        mps(i).AR = varargin{1}(i).AR;
                        mps(i).C  = varargin{1}(i).C;
                        mps(i).AC = varargin{1}(i).AC;
                    end
                    mps = reshape(mps, size(mps));
                    
                elseif isa(varargin{1}, 'Tensor')
                    % by default we take the input as AR, as canonicalize right
                    % orthogonalizes before left orthogonalization
                    for i = height(varargin{1}):-1:1
                        mps.AR = varargin{1};
                        mps.AL = varargin{1};
                    end
                    mps = canonicalize(mps);
                    
                elseif iscell(varargin{1})
                    for i = flip(1:width(varargin{1}))
                        for j = 1:height(varargin{1})
                            mps(j).AR(i) = varargin{1}{j, i};
                            mps(j).AL(i) = varargin{1}{j, i};
                        end
                    end
                    mps = canonicalize(mps);
                else
                    error('Invalid constructor for UniformMps.')
                end
                
            elseif nargin == 3
                mps.AL = varargin{1};
                mps.AR = varargin{2};
                mps.C  = varargin{3};
                
            elseif nargin == 4
                mps.AL = varargin{1};
                mps.AR = varargin{2};
                mps.C  = varargin{3};
                mps.AC = varargin{4};
                
            else
                error('Invalid constructor for UniformMps.')
            end
        end
    end
    
    methods (Static)
        function mps = new(fun, pspaces, vspaces)
            % Create a uniform matrix product state with data using a function handle.
            %
            % Usage
            % -----
            % :code:`UniformMps.new(fun, pspaces, vspaces)`
            %
            % Arguments
            % ---------
            % fun : :class:`function_handle`
            %   function to initialize the tensor.
            %
            % Repeating Aruguments
            % --------------------
            % pspaces : :class:`AbstractSpace`
            %   physical spaces for each site.
            %
            % vspaces : :class:`AbstractSpace`
            %   virtual spaces between each site. (entry `i` corresponds to left of site
            %   `i`.)
            
            arguments
                fun = []
            end
            arguments (Repeating)
                pspaces
                vspaces
            end
            
            if isempty(fun), fun = @randnc; end
            L = length(pspaces);
            
            for w = length(pspaces):-1:1
                rankdeficient = vspaces{w} * pspaces{w} < vspaces{next(w, L)} || ...
                        vspaces{w} > pspaces{w}' * vspaces{next(w, L)};
                if rankdeficient
                    error('mps:rank', ...
                        'Cannot create a full rank mps with given spaces.');
                end
                
                A{w} = Tensor.new(fun, [vspaces{w} pspaces{w}], ...
                    vspaces{next(w, L)});
            end
            
            mps = UniformMps(A);
        end
        
        function mps = randnc(pspaces, vspaces)
            % Create a uniform matrix product state with random entries.
            %
            % See Also
            % --------
            % :method:`UniformMps.new`
            
            arguments (Repeating)
                pspaces
                vspaces
            end
            args = [pspaces; vspaces];
            mps = UniformMps.new(@randnc, args{:});
        end
    end
    
    
    %% Properties
    methods
        function p = period(mps)
            % period over which the mps is translation invariant.
            p = length(mps(1).AL);
        end
        
        function d = depth(mps)
            % amount of lines in a multi-line mps.
            d = size(mps, 1);
        end
        
        function mps = horzcat(varargin)
            ALs = cellfun(@(x) x.AL, varargin, 'UniformOutput', false);
            ARs = cellfun(@(x) x.AR, varargin, 'UniformOutput', false);
            Cs =  cellfun(@(x) x.C, varargin, 'UniformOutput', false);
            ACs = cellfun(@(x) x.AC, varargin, 'UniformOutput', false);
            mps = UniformMps([ALs{:}], [ARs{:}], [Cs{:}], [ACs{:}]);
        end
        
        function mps = vertcat(varargin)
            for i = 2:length(varargin)
                assert(period(varargin{1}) == period(varargin{i}), ...
                    'Can only stack UniformMps with matching periods.')
            end
            mps = builtin('vertcat', varargin{:});
        end
        
        function s = leftvspace(mps, w)
            % return the virtual space to the left of site w.
            if nargin == 1 || isempty(w), w = 1:period(mps); end
            s = arrayfun(@leftvspace, mps.AL(w));
        end
        
        function s = pspace(mps, w)
            % return the physical space at site w.
            s = pspace(mps.AL(w));
        end
        
        function s = rightvspace(mps, w)
            % return the virtual space to the right of site w.
            if nargin == 1 || isempty(w), w = 1:period(mps); end
            s = arrayfun(@rightvspace, mps.AL(w));
        end
        
        function type = underlyingType(mps)
            type = underlyingType(mps(1).AR(1));
        end
    end
    
    
    %% Methods
    methods
        function [mps, lambda] = canonicalize(mps, kwargs)
            % Compute the center-gauged form of an mps.
            %
            % Usage
            % -----
            % :code:`[mps, lambda] = canonicalize(mps, kwargs)`
            %
            % Arguments
            % ---------
            % mps : :class:`UniformMps`
            %   input mps, from which AL or AR is used as the state, and optionally C as an
            %   initial guess for the gauge.
            %
            % Keyword Arguments
            % -----------------
            % Tol : numeric
            %   tolerance for the algorithm.
            %
            % MaxIter : integer
            %   maximum amount of iterations.
            %
            % Method : char
            %   algorithm used for decomposition. Must be 'polar', 'qr' or 'qrpos'.
            %
            % Verbosity : :class:`Verbosity`
            %   level of output.
            %
            % DiagC : logical
            %   flag to indicate if `C` needs to be diagonalized.
            %
            % ComputeAC : logical
            %   flag to indicate if `AC` needs to be computed.
            %
            % Order : 'lr' or 'rl'
            %   order of gauge fixing:
            %       'lr' uses AL as input tensors, first leftorth, then rightorth.
            %       'rl' uses AR as input tensors, first rightorth, then leftorth.
            
            arguments
                mps
                kwargs.Tol = eps(underlyingType(mps))^(3/4)
                kwargs.MaxIter = 1e3
                kwargs.Method {mustBeMember(kwargs.Method, {'polar', 'qr', 'qrpos'})} ...
                    = 'polar'
                kwargs.Verbosity = Verbosity.warn
                kwargs.DiagC = false
                kwargs.ComputeAC = true
                kwargs.Order {mustBeMember(kwargs.Order, {'lr', 'rl'})} = 'lr'
            end
            
            for i = 1:length(mps)
                if strcmp(kwargs.Order, 'rl')
                    [mps(i).AR, ~, ~, eta1]             = uniform_rightorth(...
                        mps(i).AR, [], ...
                        'Tol', kwargs.Tol, 'MaxIter', kwargs.MaxIter, ...
                        'Method', kwargs.Method, 'Verbosity', kwargs.Verbosity);
                    [mps(i).AL, mps(i).C, lambda, eta2] = uniform_leftorth(...
                        mps(i).AR, mps(i).C, ...
                        'Tol', kwargs.Tol, 'MaxIter', kwargs.MaxIter, ...
                        'Method', kwargs.Method, 'Verbosity', kwargs.Verbosity);
                else
                    [mps(i).AL, ~, ~, eta1]             = uniform_leftorth(...
                        mps(i).AL, [], ...
                        'Tol', kwargs.Tol, 'MaxIter', kwargs.MaxIter, ...
                        'Method', kwargs.Method, 'Verbosity', kwargs.Verbosity);
                    [mps(i).AR, mps(i).C, lambda, eta2] = uniform_rightorth(...
                        mps(i).AL, mps(i).C, ...
                        'Tol', kwargs.Tol, 'MaxIter', kwargs.MaxIter, ...
                        'Method', kwargs.Method, 'Verbosity', kwargs.Verbosity);
                end
            end
            
            if kwargs.DiagC
                mps = diagonalizeC(mps);
            end
            
            if kwargs.ComputeAC
                for i = 1:height(mps)
                    for w = period(mps(i)):-1:1
                        mps(i).AC(w) = multiplyright(mps(i).AL(w), ...
                            mps(i).C(w));
                    end
                end
            end
        end
        
        function mps = diagonalizeC(mps)
            % gauge transform an mps such that C is diagonal.
            
            for i = 1:height(mps)
                for w = 1:period(mps(i))
                    C_iw = mps(i).C(w);
                    [U, S, V] = tsvd(C_iw, 1, 2);
                    
                    if isdual(C_iw.codomain) ~= isdual(S.codomain)
                        U.domain = conj(U.domain);
                        S.codomain = conj(S.codomain);
                        S = twist(S, 1);
                    end
                    
                    if isdual(C_iw.domain) ~= isdual(S.domain)
                        V.codomain = conj(V.codomain);
                        S.domain = conj(S.domain);
                        S = twist(S, 2);
                    end
                    
                    ww = next(w, period(mps(i)));
                    mps(i).C(w) = S;
                    
                    mps(i).AL(ww) = multiplyleft(mps(i).AL(ww), U');
                    mps(i).AL(w)  = multiplyright(mps(i).AL(w), U);
                    
                    mps(i).AR(ww) = multiplyleft(mps(i).AR(ww), V);
                    mps(i).AR(w)  = multiplyright(mps(i).AR(w), V');
                end
            end
        end
        
        function mps = normalize(mps)
            % normalize an mps state.
            
            mps.C = arrayfun(@normalize, mps.C);
            mps.AC = arrayfun(@normalize, mps.AC);
        end
        
        function T = transfermatrix(mps1, mps2, sites, kwargs)
            % A finite matrix product operator that represents the transfer matrix of an
            % mps.
            %
            % Usage
            % -----
            % :code:`T = transfermatrix(mps1, mps2, sites, kwargs)`
            %
            % Arguments
            % ---------
            % mps1 : :class:`UniformMps`
            %   input mps for top layer.
            %
            % mps2 : :class:`UniformMps`
            %   input mps for bottom layer, by default equal to the top.
            %
            % sites : integer
            %   optionally slice the unit cell of the mps and only define the transfer
            %   matrix for this slice.
            %
            % Keyword Arguments
            % -----------------
            % Type : char
            %   'LL', 'LR', 'RL', 'RR' to determine if the top or bottom respectively are AL
            %   or AR.
            %
            % Returns
            % -------
            % T : FiniteMpo
            %   transfer matrix of an mps, acting to the left.
            
            arguments
                mps1
                mps2 = mps1
                sites = 1:period(mps1)
                kwargs.Type {mustBeMember(kwargs.Type, {'LL' 'LR' 'RL' 'RR'})} = 'RR'
            end
            
            assert(all(diff(sites) == 1), 'sites must be neighbouring and increasing.');
            
            if kwargs.Type(1) == 'L'
                A1 = mps1.AL(sites);
            else
                A1 = mps1.AR(sites);
            end
            if kwargs.Type(2) == 'L'
                A2 = mps2.AL(sites);
            else
                A2 = mps2.AR(sites);
            end
            
            T = transfermatrix(A1, A2);
        end
        
        function rho = fixedpoint(mps, type, w)
            % compute the fixed point of the transfer matrix of an mps.
            %
            % Usage
            % -----
            % :code:`rho = fixedpoint(mps, type, w)`
            %
            % Arguments
            % ---------
            % mps : :class:`UniformMps`
            %   input state.
            %
            % type : char
            %   specification of the type of transfer matrix: 
            %   general format: sprintf(%c_%c%c, side, top, bot) where side is 'l' or 'r' to
            %   determine which fixedpoint, and top and bot are 'L' or 'R' to specify
            %   whether to use AL or AR in the transfer matrix.
            %
            % w : integer
            %   position within the mps unitcell of the fixed point.
            
            arguments
                mps
                type {mustBeMember(type, ...
                    {'l_LL' 'l_LR' 'l_RL' 'l_RR' 'r_LL' 'r_LR' 'r_RL' 'r_RR'})}
                w = strcmp(type(1), 'l') * 1 + strcmp(type(1), 'r') * period(mps)
            end
            
            ww = prev(w, period(mps));
            switch type
                case 'l_RR'
                    rho = contract(mps.C(ww)', [-1 1], mps.C(ww), [1 -2], 'Rank', [1 1]);
%                     if isdual(space(rho, 1)), rho = twist(rho, 1); end
                case 'l_RL'
                    rho = mps.C(ww);
%                     if isdual(space(rho, 1)), rho = twist(rho, 1); end
                case 'l_LR'
                    rho = mps.C(ww)';
%                     if isdual(space(rho, 1)), rho = twist(rho, 1); end
                case 'l_LL'
                    rho = mps.C.eye(leftvspace(mps, w), leftvspace(mps, w));
                    if isdual(space(rho, 1)), rho = twist(rho, 1); end
                    
                case 'r_RR'
                    rho = mps.C.eye(rightvspace(mps, w)', rightvspace(mps, w)');
                    if isdual(space(rho, 2)), rho = twist(rho, 2); end
                case 'r_RL'
                    rho = twist(mps.C(w)', 2);
%                     if isdual(space(rho, 1)), rho = twist(rho, 2); end
                case 'r_LR'
                    rho = twist(mps.C(w), 2);
%                     if ~isdual(space(rho, 2)), rho = twist(rho, 2); end
                case 'r_LL'
                    rho = contract(mps.C(w), [-1 1], mps.C(w)', [1 -2], 'Rank', [1 1]);
                    rho = twist(rho, 2);
            end
        end
        
        function [V, D] = transfereigs(mps1, mps2, howmany, which, eigopts, kwargs)
            % Compute the eigenvalues of the transfer matrix of an mps.
            %
            % Usage
            % -----
            % :code:`[V, D] = transfereigs(mps1, mps2, howmany, which, eigopts, kwargs)`
            %
            % Arguments
            % ---------
            % mps1 : :class:`UniformMps`
            %   input mps for top layer.
            %
            % mps2 : :class:`UniformMps`
            %   input mps for bottom layer. Default value equal to `mps1`.
            %
            % howmany : integer
            %   number of eigenvectors and eigenvalues to compute.
            %
            % which : 'char'
            %   type of eigenvectors to target.
            %
            % Keyword Arguments
            % -----------------
            % eigopts
            %   see keyword arguments for :method:`eigs`.
            %
            % Verbosity : integer
            %   detail level for output.
            %
            % Type : 'char'
            %   type of transfer matrix to construct.
            %
            % Charge : :class:`AbstractCharge`
            %   charge of eigenvectors to target.
            
            arguments
                mps1
                mps2 = mps1
                howmany = min(20, dim(leftvspace(mps1, 1) * leftvspace(mps2, 1)'))
                which = 'largestabs'
                eigopts.KrylovDim = 100
                eigopts.MaxIter = 1000
                eigopts.ReOrth = 2
                eigopts.Tol = eps(underlyingType(mps1))^(3/4)
                kwargs.Verbosity = 0
                kwargs.Type {mustBeMember(kwargs.Type, ...
                    {'l_LL' 'l_LR' 'l_RL' 'l_RR' 'r_LL' 'r_LR' 'r_RL' 'r_RR'})} = 'r_RR'
                kwargs.Charge = []
            end
            
            T = transfermatrix(mps1, mps2, 'Type', kwargs.Type(3:4));
            if kwargs.Type(1) == 'r', T = T'; end
            
            if ~isempty(kwargs.Charge)
                Tdomain = domain(T);
                auxspace = Tdomain.new(...
                    struct('charges', kwargs.Charge, 'degeneracies', 1), ...
                    false);
                v0 = Tensor.randnc([Tdomain auxspace], []); 
            else
                v0 = [];
            end
            
            eigkwargs.Verbosity = kwargs.Verbosity;
            eigkwargs = namedargs2cell(eigopts);
            [V, D] = eigsolve(T, v0, howmany, which, eigkwargs{:});
            
            if kwargs.Type(1) == 'r', V = V'; end
            if nargout < 2, V = D; end
        end
        
        function f = fidelity(mps1, mps2, kwargs)
            arguments
                mps1
                mps2
                kwargs.KrylovDim = 30
                kwargs.MaxIter = 500
                kwargs.ReOrth = 2
                kwargs.Tol = eps(underlyingType(mps1))^(3/4)
                kwargs.Verbosity = 0
            end
            
            eigkwargs = [fieldnames(kwargs).'; struct2cell(kwargs).'];
            f = transfereigs(mps1, mps2, 1, 'largestabs', eigkwargs{:});
        end
        
        function E = expectation_value(mps1, O, mps2)
            arguments
                mps1
                O
                mps2 = mps1
            end
            
            if isa(O, 'InfJMpo')
                [GL, GR] = environments(O, mps1, mps2);
                Hs = AC_hamiltonian(O, mps1, GL, GR, period(mps1));
                H = Hs{1};
                N = size(H.R.var, 2);
                H.R.var = H.R.var(1, N, 1);
                H.O{1} = H.O{1}(:, :, N, :);
                AC_ = apply(H, mps1.AC(end));
                E = dot(AC_, mps2.AC(end));
                
            elseif isa(O, 'InfMpo')
                [GL, GR] = environments(O, mps1, mps2); % should be normalized
                Hs = AC_hamiltonian(O, mps1, GL, GR);
                E = zeros(size(Hs));
                for i = 1:length(Hs)
                    AC_ = apply(Hs{i}, mps1.AC(i));
                    E(i) = dot(AC_, mps2.AC(i));
                end
                E = prod(E);
                
            elseif isa(O, 'AbstractTensor')
                E = local_expectation_value(mps1, O);
            else
                error('Unknown operator type (%s)', class(O));
            end
        end
        
        function E = local_expectation_value(mps, O, offset)
            arguments
                mps
                O
                offset = 0   % site offset
            end
            
            local_ops = MpoTensor.decompose_local_operator(O);
            N = length(local_ops);
            
            A = [mps.AC(1 + offset) mps.AR(2:(N - 1) + offset)];
            
            T = FiniteMpo.mps_channel_operator(A, local_ops, A);
            rhoL = insert_onespace(fixedpoint(mps, 'l_LL', offset+ 1), 2, ...
                ~isdual(space(T(1).O{1}, 4)));
            rhoR = insert_onespace(fixedpoint(mps, 'r_RR', offset + N), 2, ...
                ~isdual(space(T(1).O{1}, 2)));
            E1 = apply(T, rhoL);
            E = contract(E1, 1:3, rhoR, flip(1:3));
        end
        
        function [svals, charges] = schmidt_values(mps, w)
            arguments
                mps
                w = 1
            end
            
            [svals, charges] = matrixblocks(tsvd(mps.C(w)));
            svals = cellfun(@diag, svals, 'UniformOutput', false);
        end
        
        function plot_entanglementspectrum(mps, d, w, ax)
            arguments
                mps
                d = 1:depth(mps)
                w = 1:period(mps)
                ax = []
            end
            if isempty(ax)
                figure;
                ax = gobjects(depth(mps), width(mps));
                for dd = 1:length(d)
                    for ww = 1:length(w)
                        ax(dd, ww) = subplot(length(d), length(w), ww + (dd-1)*length(w));
                    end
                end
            end
            
            lim_y = 1;
            for dd = 1:length(d)
                for ww = 1:length(w)
                    [svals, charges] = schmidt_values(mps(dd), w(ww));
                    ctr = 0;
                    hold off;
                    lim_x = 1;

                    ticks = zeros(size(svals));
                    labels = arrayfun(@string, charges, 'UniformOutput', false);
                    lengths = cellfun(@length, svals);
                    ticks = cumsum(lengths);
                    try
                        semilogy(ax(dd, ww), 1:sum(lengths), vertcat(svals{:}).', '.', 'MarkerSize', 10);
                    catch
                        bla
                    end
                    set(ax(dd, ww), 'TickLabelInterpreter', 'latex');
                    set(ax(dd, ww), 'Xtick', ticks, 'XTickLabel', labels, 'fontsize', 10, ...
                        'XtickLabelRotation', 60, 'Xgrid', 'on');
                    xlim(ax(dd, ww), [1 - 1e-8 ticks(end) + 1e-8]);

                end
            end
                
%             for ww = 1:length(w)
%                 ylim(ax(1, ww), [10^(floor(log10(lim_y))) 1]);
%             end
        end
        
        function mps = desymmetrize(mps)
            if numel(mps) > 1
                mps = arrayfun(@desymmetrize, mps);
                return
            end
            mps.AL = desymmetrize(mps.AL);
            mps.AR = desymmetrize(mps.AR);
            mps.C = desymmetrize(mps.C);
            mps.AC = desymmetrize(mps.AC);
        end
        
        xi = CorrelationLength(mps, charge);
        [epsilon, delta, spectrum] = MarekGap(mps, charge, angle, num)
        S = EntanglementEntropy(mps, loc);
        S = RenyiEntropy(mps,n, loc);
        E = ExpectationValue(mps, W, GL, GR)
        rho = LeftFixedPoint(mps1, mps2, w, choice)
        rho = RightFixedPoint(mps1, mps2, w, choice)
        sf=StaticStructureFactor(mps,S,k)
        
        out = Block(mps, opts)
        out = Split(mps, varargin)
        [out, lambda] = Truncate(mps, control, opts)
        
        [f, rho] = Fidelity(mps1, mps2, tol)
        
        mps = Conj(mps)
        
        mps = mtimes(mps, lambda)
        
        mps = ShiftUnitCell(mps,dd,dw)
        out = Rotate180(mps)
        out = Transpose(mps)
        
        mps = SendToGpu(mps)
        mps = GetFromGpu(mps)
        
        [mps, xi] = Retract(mps, eta, alpha)
        n = Inner(x, eta, xi)
        
        
    end
end

