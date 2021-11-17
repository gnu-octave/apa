classdef mpfr_t

  properties (SetAccess = protected)
    dims  % Object dimensions.
    idx   % Internal MPFR variable indices.
    cleanupObj  % Destructor object.
  end


  methods (Static)
    function num = get_data_capacity ()
      % [internal] Return the number of pre-allocated MPFR variables.

      num = mex_apa_interface (1900);
    end


    function num = get_data_size ()
      % [internal] Return the number of currently used MPFR variables.

      num = mex_apa_interface (1901);
    end


    function idx = allocate (count)
      % [internal] Return the start and end index of a newly created MPFR
      % variable for `count` elements.

      idx = mex_apa_interface (1902, count);
    end


    function mark_free (idx)
      % [internal] Mark a MPFR variable or index range as free.  It is no
      % longer safe to use that variable or index range after calling this
      % method.

      if (isa (idx, 'mpfr_t'))
        idx = idx.idx;
      end

      mex_apa_interface (1903, idx);
    end
  end


  methods (Access = private)
    function warnInexactOperation (~, ret)
      % [internal] MPFR functions returning an int return a ternary value.
      % If the ternary value is zero, it means that the value stored in the
      % destination variable is the exact result of the corresponding
      % mathematical function.  If the ternary value is positive (resp.
      % negative), it means the value stored in the destination variable is
      % greater (resp. lower) than the exact result.  For example with the
      % MPFR_RNDU rounding mode, the ternary value is usually positive, except
      % when the result is exact, in which case it is zero.  In the case of an
      % infinite result, it is considered as inexact when it was obtained by
      % overflow, and exact otherwise.  A NaN result (Not-a-Number) always
      % corresponds to an exact return value.  The opposite of a returned
      % ternary value is guaranteed to be representable in an int.

      if (any (ret(:)))
        fcn = dbstack ();
        fcn = fcn(2);  % caller
        [~, fname, fext] = fileparts (fcn.file);
        fcn = sprintf ('%s%s (%s at line %d)', fname, fext, fcn.name, fcn.line);
        warning ('mpfr_t:inexactOperation', ...
                 ['%s: Inexact operation.\n\n', ...
                  'Suppress MPFR_T inexactness warning messages with:\n\n', ...
                  '\twarning (''off'', ''mpfr_t:inexactOperation'')\n'], fcn);
      end
    end
  end


  methods (Static, Access = private)
    function c = call_comparison_op (a, b, op)
      % [internal] Handle calls to all sorts of MPFR comparision functions.
      if (isa (a, 'mpfr_t'))
        new_dims = a.dims;
      else
        a = mpfr_t (a);
        new_dims = b.dims;
      end
      if (~isa (b, 'mpfr_t'))
         b = mpfr_t (b);
      end
      c = (op (a, b) ~= 0);
      c = reshape (c, new_dims);
    end
  end


  methods
    % More information about class methods.
    % https://octave.org/doc/v6.4.0/Operator-Overloading.html
    % https://www.mathworks.com/help/matlab/matlab_oop/implementing-operators-for-your-class.html
    % https://www.mathworks.com/help/matlab/matlab_oop/methods-that-modify-default-behavior.html


    % Defined in extra files.
    varargout = subsref (obj, s, rnd)
    obj = subsasgn (obj, s, b, rnd)


    function obj = mpfr_t (x, prec, rnd)
      % Construct a mpfr_t variable of precision `prec` from `x` using rounding
      % mode `rnd`.

      if (nargin < 1)
        error ('mpfr_t:mpfr_t', 'At least one argument must be provided.');
      end

      if (~ismatrix (x))
        error ('mpfr_t:mpfr_t', ...
          'Only two dimensional matrix input is supported.');
      end

      if (nargin < 2)
        prec = mex_apa_interface (1002);  % mpfr_get_default_prec
      end
      if (nargin < 3)
        rnd = mex_apa_interface (1162);  % mpfr_get_default_rounding_mode
      end

      if (ischar (x))
        x = {x};
      end
      if (isa (x, 'mpfr_t'))
        obj.dims = x.dims;
        prec = max (mex_apa_interface (1004, x.idx));  % mpfr_get_prec
      else
        obj.dims = size (x);
      end
      num_elems = prod (obj.dims);
      obj.idx = mex_apa_interface (1902, num_elems)';  % mpfr_t.allocate

      % Register destructor
      obj.cleanupObj = onCleanup(@() mex_apa_interface (1903, obj.idx));

      mex_apa_interface (1003, obj.idx, prec);  % mpfr_set_prec

      if (isa (x, 'mpfr_t'))
        ret = mpfr_set (obj.idx, x.idx, rnd);
      elseif (isnumeric (x))
        ret = mex_apa_interface (1006, obj.idx, x(:), rnd);  % mpfr_set_d
      elseif (iscellstr (x))
        [ret, strpos] = mpfr_strtofr (obj.idx, x(:), 0, rnd);
        bad_strs = (cellfun (@numel, x(:)) >= strpos);
        if (any (bad_strs))
          % Assign x to mpfr variable using slower subsasgn function.
          %
          % https://www.mathworks.com/help/matlab/ref/subsasgn.html
          % (Matlab 2021b, Tips)
          %
          % > Within the subsasgn method defined by a class, MATLAB calls the
          % > built-in subsasgn.  Calling the built-in enables you to use the
          % > default indexing behavior when defining specialized indexing.
          %
          s = struct ('type', '()', 'subs', {{':'}});
          obj.subsasgn (s, x(:), rnd);
        end
      else
        ret = 0;
      end
      obj.warnInexactOperation (ret);
    end


    function prec = prec (obj)
      % Return the precision of obj, i.e., the number of bits used to store
      % its significant.

      prec = mpfr_get_prec (obj);
    end


    function d = double (obj, rnd)
      % Return a double approximation of `obj` using rounding mode `rnd`.

      if (nargin < 2)
        rnd = mpfr_get_default_rounding_mode ();
      end
      d = reshape (mpfr_get_d (obj, rnd), obj.dims(1), obj.dims(2));
    end


    function cstr = cellstr (obj, fmt, base, rnd)
      % Return a cell array of character vectors of `obj` using digits in base
      % `base` and rounding mode `rnd`.
      %
      % `fmt`:
      %   - 'fixed-point': e.g. "0.125"
      %   - 'scientific':  e.g. "1.25e-01"
      %
      % `base`: scalar integer from 2 to 62 (default: 10 [decimal]).
      %
      % `rnd`: scalar integer (default: `mpfr_get_default_rounding_mode()`)
      %

      if (nargin < 4)
        rnd = mpfr_get_default_rounding_mode ();
      end
      if (nargin < 3)
        base = 10;
      end
      if (nargin < 2)
        fmt = 'fixed-point';
      else
        fmt = validatestring (fmt, {'fixed-point', 'scientific'});
      end

      % Get string representation of all elements.
      [significant, exp] = mpfr_get_str (base, 0, obj.idx, rnd);

      is_negative = cellfun (@(str) (str(1) == '-'), significant);
      if (strcmp (fmt, 'scientific'))
        % Add decimal point.
        significant = cellfun ( ...
          @(str,neg) [str(1:(1 + neg)), '.', str((2 + neg):end)], ...
          significant, num2cell (is_negative), 'UniformOutput', false);
        exp = exp - 1;
      else
        % Remove '-' sign.
        significant(is_negative) = cellfun (@(str) str(2:end), ...
          significant(is_negative), 'UniformOutput', false);

        % Add leading zeros.
        zeropad = 1 - exp;
        exp(zeropad >= 0) = 1;
        zeropad(zeropad < 0) = 0;
        zeropad = num2cell (zeropad);
        zeropad = cellfun (@(num) repmat('0', 1, num), zeropad, ...
                           'UniformOutput', false);
        significant = strcat (zeropad, significant);

        % Add decimal point.
        significant = cellfun ( ...
          @(str,exp) [str(1:exp), '.', str(exp+1:end)], ...
          significant, num2cell(exp), 'UniformOutput', false);

        % Add '-' sign.
        significant(is_negative) = cellfun (@(str) ['-', str], ...
          significant(is_negative), 'UniformOutput', false);
      end

      % Remove trailing zeros.
      significant = cellfun (@(str) regexprep (str, '[0]+$', ''), ...
        significant, 'UniformOutput', false);

      if (strcmp (fmt, 'scientific'))
        % Handle created zeros '0.'.
        idxs = strcmp (significant, '0.');
        significant(idxs) = {'0'};
        exp(idxs) = 0;

        % Handle created zeros '-0.'.
        idxs = strcmp (significant, '-0.');
        significant(idxs) = {'-0'};
        exp(idxs) = 0;
      end

      % Remove trailing '.' signs.
      significant = cellfun (@(str) regexprep (str, '\.$', ''), ...
        significant, 'UniformOutput', false);

      if (strcmp (fmt, 'scientific'))
        % Add base and exponent.
        if (base == 10)
          significant = cellfun ( ...
            @(str,exp) sprintf ('%se%+03d' , str, exp), ...
            significant, num2cell(exp), 'UniformOutput', false);
        else
          significant = cellfun ( ...
            @(str,exp) sprintf ('%s * %d^(%d)' , str, base, exp), ...
            significant, num2cell(exp), 'UniformOutput', false);
        end
      end
      
      % Handle '@NaN@', @Inf@', and '-@Inf@'.
      if (strcmp (fmt, 'scientific'))
        significant(strcmp (significant, '@.NaN@e-01'))  = {'NaN'};
        significant(strcmp (significant, '@.Inf@e-01'))  = {'Inf'};
        significant(strcmp (significant, '-@.Inf@e-01')) = {'-Inf'};
      else
        significant(strcmp (significant, '0.@NaN@'))  = {'NaN'};
        significant(strcmp (significant, '0.@Inf@'))  = {'Inf'};
        significant(strcmp (significant, '-0.@Inf@')) = {'-Inf'};
      end

      % Adapt to size of obj.
      [M, N] = deal (obj.dims(1), obj.dims(2));
      cstr = reshape (significant, M, N);
    end


    function disp (obj)
      % Object display.

      if (isscalar (obj))
        % Get display format parameters.
        fmt = apa ('format.fmt');
        base = apa ('format.base');
        inner_padding = apa ('format.inner_padding');
        break_at_col  = apa ('format.break_at_col');
        rnd = mpfr_get_default_rounding_mode ();
        N = obj.dims(2);

        % Get cellstr representation.
        cstr = cellstr (obj, fmt, base, rnd);

        % Right align columns.
        spacepad = cellfun (@length, cstr);
        spacepad = repmat (max (spacepad, [], 1), size (spacepad, 1), 1) ...
                 - spacepad;
        spacepad = num2cell (spacepad);
        spacepad = cellfun (@(num) repmat(' ', 1, num), spacepad, ...
                            'UniformOutput', false);
        cstr = strcat (spacepad, cstr);

        % Determine column paging.
        col_lengths = sort (cellfun (@length, cstr(1,:)), 'descend');
        col_lengths = col_lengths + inner_padding;
        disp_max_cols = find (cumsum (col_lengths) < break_at_col, 1, 'last');
        disp_max_cols = max ([1, disp_max_cols]);

        % Final output.
        inner_padding = repmat (' ', 1, inner_padding);
        ofun = @(cols) fprintf ( ...
          [repmat([inner_padding, '%s'], 1, size (cols, 1)), '\n'], cols{:});

        if (disp_max_cols == N)
          ofun (cstr');
        else  % Output with column paging.
          for i = 1:disp_max_cols:N
            if ((length (i:N) == 1) || (disp_max_cols == 1))
              fprintf ('  Column %d\n\n', i);
              j = i;
            else
              j = min (N, i + disp_max_cols - 1);
              fprintf ('  Columns %d through %d\n\n', i, j);
            end
            ofun (cstr(:,i:j)');
            fprintf ('\n');
          end
        end
      else
        builtin ('disp', obj);
      end
    end


    function c = plus (a, b, rnd, prec)
      % Binary addition `c = a + b` using rounding mode `rnd`.
      %
      % If no rounding mode `rnd` is given, the default rounding mode is used.
      %
      % If no precision `prec` is given for `c` the maximum precision of a and
      % is used b.

      if (nargin < 3)
        rnd = mpfr_get_default_rounding_mode ();
      end
      if (nargin < 4)
        prec = [];
      end
      if (isnumeric (a))
        c = plus (b, a, rnd, prec);
      elseif (isa (a, 'mpfr_t') && isnumeric (b))
        if (isscalar (b) || isequal (a.dims, size (b)))
          if (isempty (prec))
            prec = max (mpfr_get_prec (a));
          end
          cc = mpfr_t (zeros (a.dims), prec);
        else
          error ('mpfr_t:plus', 'Incompatible dimensions of a and b.');
        end
        ret = mpfr_add_d (cc, a, double (b(:)), rnd);
        cc.warnInexactOperation (ret);
        c = cc;  % Do not assign c before calculation succeeded!
      elseif (isa (a, 'mpfr_t') && isa (b, 'mpfr_t'))
        if (isempty (prec))
          prec = max (max (mpfr_get_prec (a)), max (mpfr_get_prec (b)));
        end
        if (isequal (a.dims, b.dims) || isequal (b.dims, [1 1]))
          cc = mpfr_t (zeros (a.dims), prec);
        elseif (isequal (a.dims, [1 1]))
          cc = mpfr_t (zeros (b.dims), prec);
        else
          error ('mpfr_t:plus', 'Incompatible dimensions of a and b.');
        end
        ret = mpfr_add (cc, a, b, rnd);
        cc.warnInexactOperation (ret);
        c = cc;  % Do not assign c before calculation succeeded!
      else
        error ('mpfr_t:plus', 'Invalid operands a and b.');
      end
    end


    function c = minus (a, b, rnd, prec)
      % Binary subtraction `c = a - b` using rounding mode `rnd`.
      %
      % If no rounding mode `rnd` is given, the default rounding mode is used.
      %
      % If no precision `prec` is given for `c` the maximum precision of a and
      % is used b.

      if (nargin < 3)
        rnd = mpfr_get_default_rounding_mode ();
      end
      if (nargin < 4)
        prec = [];
      end
      if (isnumeric (a) && isa (b, 'mpfr_t'))
        if (isscalar (a) || isequal (size (a), b.dims))
          if (isempty (prec))
            prec = max (mpfr_get_prec (b));
          end
          cc = mpfr_t (zeros (b.dims), prec);
        else
          error ('mpfr_t:minus', 'Incompatible dimensions of a and b.');
        end
        ret = mpfr_d_sub (cc, double (a(:)), b, rnd);
        c = cc;  % Do not assign c before calculation succeeded!
      elseif (isa (a, 'mpfr_t') && isnumeric (b))
        if (isscalar (b) || isequal (a.dims, size (b)))
          if (isempty (prec))
            prec = max (mpfr_get_prec (a));
          end
          cc = mpfr_t (zeros (a.dims), prec);
        else
          error ('mpfr_t:minus', 'Incompatible dimensions of a and b.');
        end
        ret = mpfr_sub_d (cc, a, double (b(:)), rnd);
        c = cc;  % Do not assign c before calculation succeeded!
      elseif (isa (a, 'mpfr_t') && isa (b, 'mpfr_t'))
        if (isempty (prec))
          prec = max (max (mpfr_get_prec (a)), max (mpfr_get_prec (b)));
        end
        if (isequal (a.dims, b.dims) || isequal (b.dims, [1 1]))
          cc = mpfr_t (zeros (a.dims), prec);
        elseif (isequal (a.dims, [1 1]))
          cc = mpfr_t (zeros (b.dims), prec);
        else
          error ('mpfr_t:minus', 'Incompatible dimensions of a and b.');
        end
        ret = mpfr_sub (cc, a, b, rnd);
        c = cc;  % Do not assign c before calculation succeeded!
      else
        error ('mpfr_t:minus', 'Invalid operands a and b.');
      end
      c.warnInexactOperation (ret);
    end


    function c = uminus (a)
      % Unary minus `c = -a`

      c = minus (0, a);
    end


    function c = uplus (a)
      % Unary plus `c = +a`

      c = a;
    end


    function c = times (a, b, rnd, prec)
      % Element-wise multiplication `c = a .* b` using rounding mode `rnd`.
      %
      % If no rounding mode `rnd` is given, the default rounding mode is used.
      %
      % If no precision `prec` is given for `c` the maximum precision of a and
      % is used b.

      if (nargin < 3)
        rnd = mpfr_get_default_rounding_mode ();
      end
      if (nargin < 4)
        prec = [];
      end
      if (isnumeric (a))
        c = times (b, a);
      elseif (isa (a, 'mpfr_t') && isnumeric (b))
        if (isscalar (b) || isequal (a.dims, size (b)))
          if (isempty (prec))
            prec = max (mpfr_get_prec (a));
          end
          cc = mpfr_t (zeros (a.dims), prec);
        else
          error ('mpfr_t:times', 'Incompatible dimensions of a and b.');
        end
        ret = mpfr_mul_d (cc, a, double (b(:)), rnd);
        cc.warnInexactOperation (ret);
        c = cc;  % Do not assign c before calculation succeeded!
      elseif (isa (a, 'mpfr_t') && isa (b, 'mpfr_t'))
        if (isempty (prec))
          prec = max (max (mpfr_get_prec (a)), max (mpfr_get_prec (b)));
        end
        if (isequal (a.dims, b.dims) || isequal (b.dims, [1 1]))
          cc = mpfr_t (zeros (a.dims), prec);
        elseif (isequal (a.dims, [1 1]))
          cc = mpfr_t (zeros (b.dims), prec);
        else
          error ('mpfr_t:times', 'Incompatible dimensions of a and b.');
        end
        ret = mpfr_mul (cc, a, b, rnd);
        cc.warnInexactOperation (ret);
        c = cc;  % Do not assign c before calculation succeeded!
      else
        error ('mpfr_t:times', 'Invalid operands a and b.');
      end
    end


    function c = mtimes (a, b, rnd, prec, strategy)
      % Matrix multiplication `c = a * b` using rounding mode `rnd`.
      %
      % If no rounding mode `rnd` is given, the default rounding mode is used.
      %
      % If no precision `prec` is given for `c` the maximum precision of a and
      % is used b.

      if (nargin < 3)
        rnd = mpfr_get_default_rounding_mode ();
      end
      if (nargin < 4)
        prec = [];
      end
      if (nargin < 5)
        strategy = 7;
      end

      % TODO: mpfr_t * double
      if (~ isa (a, 'mpfr_t'))
        a = mpfr_t (a);
      end
      if (~ isa (b, 'mpfr_t'))
        b = mpfr_t (b);
      end

      if (isempty (prec))
        precA = mpfr_get_prec (a);
        precB = mpfr_get_prec (b);
        prec = max ([precA(:); precB(:)]);
      end

      sizeA = a.dims;
      sizeB = b.dims;
      if (sizeA(2) ~= sizeB(1))
        error ('mpfr_t:mtimes', 'Incompatible dimensions of a and b.');
      end

      c = mpfr_t (zeros (sizeA(1), sizeB(2)), prec, rnd);
      ret = mex_apa_interface (2001, c.idx, a.idx, b.idx, prec, rnd, ...
                               sizeA(1), strategy);
      c.warnInexactOperation (ret);
    end


    function c = rdivide (a, b, rnd, prec)
      % Right element-wise division `c = a ./ b` using rounding mode `rnd`.
      %
      % If no rounding mode `rnd` is given, the default rounding mode is used.
      %
      % If no precision `prec` is given for `c` the maximum precision of a and
      % is used b.

      if (nargin < 3)
        rnd = mpfr_get_default_rounding_mode ();
      end
      if (nargin < 4)
        prec = [];
      end
      if (isnumeric (a) && isa (b, 'mpfr_t'))
        if (isscalar (a) || isequal (size (a), b.dims))
          if (isempty (prec))
            prec = max (mpfr_get_prec (b));
          end
          cc = mpfr_t (zeros (b.dims), prec);
        else
          error ('mpfr_t:rdivide', 'Incompatible dimensions of a and b.');
        end
        ret = mpfr_d_div (cc, double (a(:)), b, rnd);
        c = cc;  % Do not assign c before calculation succeeded!
      elseif (isa (a, 'mpfr_t') && isnumeric (b))
        if (isscalar (b) || isequal (a.dims, size (b)))
          if (isempty (prec))
            prec = max (mpfr_get_prec (a));
          end
          cc = mpfr_t (zeros (a.dims), prec);
        else
          error ('mpfr_t:rdivide', 'Incompatible dimensions of a and b.');
        end
        ret = mpfr_div_d (cc, a, double (b(:)), rnd);
        c = cc;  % Do not assign c before calculation succeeded!
      elseif (isa (a, 'mpfr_t') && isa (b, 'mpfr_t'))
        if (isempty (prec))
          prec = max (max (mpfr_get_prec (a)), max (mpfr_get_prec (b)));
        end
        if (isequal (a.dims, b.dims) || isequal (b.dims, [1 1]))
          cc = mpfr_t (zeros (a.dims), prec);
        elseif (isequal (a.dims, [1 1]))
          cc = mpfr_t (zeros (b.dims), prec);
        else
          error ('mpfr_t:rdivide', 'Incompatible dimensions of a and b.');
        end
        ret = mpfr_div (cc, a, b, rnd);
        c = cc;  % Do not assign c before calculation succeeded!
      else
        error ('mpfr_t:rdivide', 'Invalid operands a and b.');
      end
      c.warnInexactOperation (ret);
    end


    function c = ldivide (a, b, varargin)
      % Left element-wise division `c = a .\ b` using rounding mode `rnd`.
      %
      % If no rounding mode `rnd` is given, the default rounding mode is used.
      %
      % If no precision `prec` is given for `c` the maximum precision of a and
      % is used b.

      c = rdivide (b, a, varargin{:});
    end


    function x = mrdivide (b, a, rnd, prec)
      % Right matrix division `x = B / A` using rounding mode `rnd`.
      %
      % Find x, such that x*A = B.
      %
      % If no rounding mode `rnd` is given, the default rounding mode is used.
      %
      % If no precision `prec` is given for `c` the maximum precision of a and
      % is used b.

      if (nargin < 3)
        rnd = mpfr_get_default_rounding_mode ();
      end
      if (nargin < 4)
        prec = [];
      end

      if ((isnumeric (a) && isscalar (a)) ...
          || (isa (a, 'mpfr_t') && (prod (a.dims) == 1)))
        x = rdivide (b, a, rnd, prec);
      else
        error ('mpfr_t:mrdivide', ...
          'Solving systems of linear equations is not yet supported.');
      end
    end


    function x = mldivide (a, b, rnd, prec)
      % Left matrix division `x = A \ B` using rounding mode `rnd`.
      %
      % Find x, such that A*x = B.
      %
      % If no rounding mode `rnd` is given, the default rounding mode is used.
      %
      % If no precision `prec` is given for `c` the maximum precision of a and
      % is used b.

      if (nargin < 3)
        rnd = mpfr_get_default_rounding_mode ();
      end

      if ((isnumeric (a) && isscalar (a)) ...
          || (isa (a, 'mpfr_t') && (prod (a.dims) == 1)))
        x = rdivide (b, a, rnd, prec);
        return;
      end
      
      A = mpfr_t (a);
      x = mpfr_t (b);
      
      if (nargin < 4)
        prec = max (mpfr_get_prec (A));
      end
      
      sizeA = A.dims;
      if (sizeA(1) == sizeA(2))
        % A and x are overwritten after the function call!
        [ret, INFO] = mex_apa_interface (2003, A.idx, x.idx, prec, rnd);
      else
        error ('mpfr_t:mrdivide', ...
          'Only square systems of linear equations are yet supported.');
      end
      
      if (INFO > 0)
        warning ('mpfr_t:mrdivide', ...
                 'LU factorization reported zero pivot at %d.', INFO);
      end
      A.warnInexactOperation (ret);
    end


    function c = power (a, b, rnd, prec)
      % Element-wise power `c = a.^b` using rounding mode `rnd`.
      %
      % If no rounding mode `rnd` is given, the default rounding mode is used.
      %
      % If no precision `prec` is given for `c` the maximum precision of a and
      % is used b.

      if (nargin < 3)
        rnd = mpfr_get_default_rounding_mode ();
      end
      if (nargin < 4)
        prec = [];
      end
      if (isa (a, 'mpfr_t') && isnumeric (b))
        if (isscalar (b) || isequal (a.dims, size (b)))
          if (isempty (prec))
            prec = max (mpfr_get_prec (a));
          end
          cc = mpfr_t (zeros (a.dims), prec);
        else
          error ('mpfr_t:power', 'Incompatible dimensions of a and b.');
        end
        ret = mpfr_pow_si (cc, a, double (b(:)), rnd);
        c = cc;  % Do not assign c before calculation succeeded!
      elseif (isa (a, 'mpfr_t') && isa (b, 'mpfr_t'))
        if (isempty (prec))
          prec = max (max (mpfr_get_prec (a)), max (mpfr_get_prec (b)));
        end
        if (isequal (a.dims, b.dims) || isequal (b.dims, [1 1]))
          cc = mpfr_t (zeros (a.dims), prec);
        elseif (isequal (a.dims, [1 1]))
          cc = mpfr_t (zeros (b.dims), prec);
        else
          error ('mpfr_t:power', 'Incompatible dimensions of a and b.');
        end
        ret = mpfr_pow (cc, a, b, rnd);
        c = cc;  % Do not assign c before calculation succeeded!
      else
        error ('mpfr_t:power', 'Invalid operands a and b.');
      end
      c.warnInexactOperation (ret);
    end


    function c = mpower (a, b, rnd, prec)
      % Matrix power `c = A ^ B` using rounding mode `rnd`.
      %
      % If no rounding mode `rnd` is given, the default rounding mode is used.
      %
      % If no precision `prec` is given for `c` the maximum precision of a and
      % is used b.

      if (nargin < 3)
        rnd = mpfr_get_default_rounding_mode ();
      end
      if (nargin < 4)
        prec = [];
      end

      if (((isnumeric (a) && isscalar (a)) ...
           || (isa (a, 'mpfr_t') && (prod (a.dims) == 1))) ...
          && ((isnumeric (b) && isscalar (b)) ...
              || (isa (b, 'mpfr_t') && (prod (b.dims) == 1))))
        c = power (a, b, rnd, prec);
      else
        error ('mpfr_t:mrdivide', ...
          'Matrix power not yet supported.');
      end
    end


    function c = lt (a, b)
      % Less than `c = (a < b)`.

      c = mpfr_t.call_comparison_op (a, b, @mpfr_less_p);
    end


    function c = gt (a, b)
      % Greater than `a > b`.

      c = mpfr_t.call_comparison_op (a, b, @mpfr_greater_p);
    end


    function c = le (a, b)
      % Less than or equal to `a <= b`.

      c = mpfr_t.call_comparison_op (a, b, @mpfr_lessequal_p);
    end


    function c = ge (a, b)
      % Greater than or equal to `a >= b`.

      c = mpfr_t.call_comparison_op (a, b, @mpfr_greaterequal_p);
    end


    function c = ne (a, b)
      % Not equal to `a ~= b`.

      c = ~eq (a, b);
    end


    function c = eq (a, b)
      % Equality `a == b`.

      c = mpfr_t.call_comparison_op (a, b, @mpfr_equal_p);
    end


    function and (varargin)
      % Logical AND `a & b`.
      error ('mpfr_t:and', 'Logical AND not supported for MPFR_T variables.');
    end


    function or (varargin)
      % Logical OR `a | b`.
      error ('mpfr_t:or', 'Logical OR not supported for MPFR_T variables.');
    end


    function not (varargin)
      % Logical NOT `~a`.
      error ('mpfr_t:not', 'Logical NOT not supported for MPFR_T variables.');
    end


    function colon (varargin)
      % Colon operator `a:b` or `a:d:b`.
      error ('mpfr_t:colon', 'Colon not supported for MPFR_T variables.');
    end


    function b = ctranspose (a, rnd)
      % Complex conjugate matrix transpose `b = a'` using rounding mode `rnd`.

      if (nargin < 2)
        rnd = mpfr_get_default_rounding_mode ();
      end

      b = transpose (a, rnd);
    end


    function b = transpose (a, rnd)
      % Matrix transpose `b = a.'` using rounding mode `rnd`.

      if (nargin < 2)
        rnd = mpfr_get_default_rounding_mode ();
      end

      % Allocate memory for b.
      b = mpfr_t (nan (fliplr (a.dims)), max (mpfr_get_prec (a)), rnd);

      ret = mex_apa_interface (2000, b.idx, a.idx, rnd, b.dims(1));
      a.warnInexactOperation (ret);
    end


    function c = cat (dim, varargin)
      % Concatenate arrays along dimension `dim`.
      %
      % The resulting matrix has the maximal used precision from the input
      % arrays `a, b, ...` and copies the data using the default rounding mode.

      N = length (varargin);
      is_mpfrt_t = cellfun (@(x) isa (x, 'mpfr_t'), varargin);
      all_dims = cell (size (varargin));
      all_dims(is_mpfrt_t) = cellfun (@(x) x.dims', varargin(is_mpfrt_t), ...
                                      'UniformOutput', false);
      all_dims(~is_mpfrt_t) = cellfun (@(x) size(x)', varargin(~is_mpfrt_t), ...
                                       'UniformOutput', false);

      % Check dimension length consistency.
      dim_len = cellfun (@length, all_dims);
      if (~ all (dim_len == dim_len(1)))
        error ('mpfr_t:cat:badDimensions', ...
               'Arguments have different dimensions.');
      end
      dim_len = dim_len(1);

      % Check dim-dimension consistency.
      all_dims = [all_dims{:}];
      all_dims_cons = all (all_dims == repmat (all_dims(:,1), 1, N), 2);
      all_dims_cons(dim) = true;
      if (~ all (all_dims_cons))
        error ('mpfr_t:cat:badDimensions', ...
               'Arguments differ in dimension %d.', find (~all_dims_cons, 1));
      end

      % Determine maximal precision.
      prec = max (cellfun (@(x) max (mpfr_get_prec (x)), varargin(is_mpfrt_t)));

      % Determine subsasgn indices.
      ii = cumsum ([0, all_dims(dim,:)]);
      all_dims = all_dims(:,1);
      all_dims(dim) = ii(end);

      % Create output variable.
      c = mpfr_t (zeros (all_dims(:)'), prec);

      % Copy elements to concatenate.
      s.type = '()';
      s.subs = repmat ({':'}, 1, dim_len);
      rnd = mpfr_get_default_rounding_mode ();
      for i = 1:N
        s.subs{dim} = (ii(i) + 1):ii(i+1);
        c.subsasgn (s, varargin{i}, rnd);
      end
    end


    function c = vertcat (varargin)
      % Vertical concatenation `c = [a; b; ...]`.
      %
      % The resulting matrix has the maximal used precision from the input
      % arrays `a; b; ...` and copies the data using the default rounding mode.

      c = cat (1, varargin{:});
    end


    function c = horzcat (varargin)
      % Horizontal concatenation `c = [a, b, ...]`.
      %
      % The resulting matrix has the maximal used precision from the input
      % arrays `a, b, ...` and copies the data using the default rounding mode.

      c = cat (2, varargin{:});
    end


    function c = end (varargin)
      % Return last object index `obj(1:end)`.

      switch (varargin{3})
        case 1
          c = prod (varargin{1}.dims);
        case 2
          c = varargin{1}.dims(varargin{2});
        otherwise
          error ('mpfr_t:end', ...
                 'MPFR_T variables can only be indexed in two dimensions.');
      end
    end


    function subsindex (varargin)
      % Subscript index `c = b(a)`.

      error ('mpfr_t:vertcat', 'MPFR_T variables cannot be used as index.');
    end


    function b = sqrt (a, rnd, prec)
      % Square root `b = sqrt(a)` using rounding mode `rnd`.
      %
      % If no rounding mode `rnd` is given, the default rounding mode is used.
      %
      % If no precision `prec` is given for `b` the maximum precision of a.

      if (nargin < 2)
        rnd = mpfr_get_default_rounding_mode ();
      end
      if (nargin < 3)
        prec = max (mpfr_get_prec (a));
      end

      bb = mpfr_t (zeros (a.dims), prec);
      ret = mpfr_sqrt (bb, a, rnd);
      a.warnInexactOperation (ret);
      b = bb;  % Do not assign b before calculation succeeded!
    end


    function b = abs (a, rnd, prec)
      % Absolute value `b = abs(a)` using rounding mode `rnd`.
      %
      % If no rounding mode `rnd` is given, the default rounding mode is used.
      %
      % If no precision `prec` is given for `b` the maximum precision of a.

      if (nargin < 2)
        rnd = mpfr_get_default_rounding_mode ();
      end
      if (nargin < 3)
        prec = max (mpfr_get_prec (a));
      end

      bb = mpfr_t (zeros (a.dims), prec);
      ret = mpfr_abs (bb, a, rnd);
      a.warnInexactOperation (ret);
      b = bb;  % Do not assign b before calculation succeeded!
    end


    function [L, U, P] = lu (a, outputForm, prec, rnd)
      % LU matrix factorization.
      %
      %   [L,U]   = lu (A)
      %   [L,U,P] = lu (A)
      %   [__]    = lu (A, outputForm, prec, rnd)
      %

      A = mpfr_t (a);
      if (nargin < 4)
        rnd = mpfr_get_default_rounding_mode ();
      end
      if (nargin < 3)
        prec = max (mpfr_get_prec (A));
      end
      if ((nargin < 2) || isempty (outputForm))
        outputForm = 'matrix';
      else
        outputForm = validatestring (outputForm, {'matrix', 'vector'});
      end

      sizeA = A.dims;
      L = mpfr_t (zeros (sizeA(1), min (sizeA)), prec, rnd);
      U = mpfr_t (zeros (min (sizeA), sizeA(2)), prec, rnd);

      % A is overwritten after the function call!
      if (nargout == 2)
        [ret, INFO] = mex_apa_interface (2002, L.idx, U.idx, A.idx, ...
                                         prec, rnd, sizeA(1));
      else
        [ret, INFO, P] = mex_apa_interface (2002, L.idx, U.idx, A.idx, ...
                                            prec, rnd, sizeA(1));
        if (strcmp (outputForm, 'matrix'))
          p = P;
          P = eye (sizeA (1));
          P = P(p,:);
        end
      end

      if (INFO > 0)
        warning ('mpfr_t:lu:zeroPivot', ...
                 'LU factorization reported zero pivot in step %d.', INFO);
      end
      A.warnInexactOperation (ret);
    end

  end

end
