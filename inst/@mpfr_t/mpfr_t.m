classdef mpfr_t

  properties (SetAccess = protected)
    dims  % Original object dimensions.
    idx   % MPFR variable indices.
  end


  methods (Static)
    function num = get_data_capacity ()
      % [internal] Return the number of pre-allocated MPFR variables.
      num = mpfr_ ('get_data_capacity');
    end

    function num = get_data_size ()
      % [internal] Return the number of currently used MPFR variables.
      num = mpfr_ ('get_data_size');
    end

    function prec = get_default_prec ()
      % Return the current default MPFR precision in bits.
      prec = mpfr_ ('get_default_prec');
    end

    function set_default_prec (prec)
      % Set the default precision to be exactly prec bits, where prec can be
      % any integer between MPFR_PREC_MIN and MPFR_PREC_MAX.  The precision of
      % a variable means the number of bits used to store its significand. All
      % subsequent calls to mpfr will use this precision, but previously
      % initialized variables are unaffected.  The default precision is set to
      % 53 bits initially.
      mpfr_ ('set_default_prec', prec);
    end

    function rnd = get_default_rounding_mode ()
      % Get the default rounding mode.  See set_default_rounding_mode for the
      % meaning of the values.
      rnd = mpfr_ ('get_default_rounding_mode');
    end

    function set_default_rounding_mode (rnd)
      % Set the default rounding mode to rnd.  The default rounding mode is
      % to nearest initially.
      %
      % -1.0 = MPFR_RNDD: round toward minus infinity
      %                   (roundTowardNegative in IEEE 754-2008).
      %  0.0 = MPFR_RNDN: round to nearest, with the even rounding rule
      %                   (roundTiesToEven in IEEE 754-2008); see details below.
      %  1.0 = MPFR_RNDU: round toward plus infinity
      %                   (roundTowardPositive in IEEE 754-2008).
      %  2.0 = MPFR_RNDZ: round toward zero (roundTowardZero in IEEE 754-2008).
      %  3.0 = MPFR_RNDA: round away from zero.
      mpfr_ ('set_default_rounding_mode', rnd);
    end
  end


  methods
    function obj = mpfr_t (x, prec, rnd)
      if (nargin < 1)
        error ('mpfr_t:mpfr_t', 'At least one argument must be provided.');
      end

      if (~ismatrix (x))
        error ('mpfr_t:mpfr_t', ...
          'Only two dimensional matrix input is supported.');
      end

      if (nargin < 2)
        prec = mpfr_ ('get_default_prec');
      end
      if (nargin < 3)
        rnd = mpfr_ ('get_default_rounding_mode');
      end

      if (ischar (x))
        obj = mpfr_t ({x}, prec, rnd);
      elseif (isnumeric (x))
        obj.dims = size (x);
        obj.idx = mpfr_ ('mex_mpfr_allocate', prod (obj.dims))';
        mpfr_ ('set_prec', obj.idx, prec);
        mpfr_ ('set_d', obj.idx, x(:), rnd);
      elseif (iscellstr (x))
        obj.dims = size (x);
        obj.idx = mpfr_ ('mex_mpfr_allocate', prod (obj.dims))';
        mpfr_ ('set_prec', obj.idx, prec);
        [ret, strpos] = mpfr_ ('strtofr', obj.idx, x(:), 0, rnd);
        if (any (ret))
          warning ('mpfr_t:inexact_conversion', ...
                   'Conversion of %d value(s) was inexact.', sum (ret ~= 0));
        end
        bad_strs = (cellfun (@numel, x(:)) >= strpos);
        if (any (bad_strs))
          warning ('mpfr_t:bad_conversion', ...
                   'Conversion of %d value(s) failed due to bad input.', ...
                   sum (bad_strs));
        end
      elseif (isa (x, 'mpfr_t'))
        error ('mpfr_t:mpfr_t', 'TODO');
      else
        error ('mpfr_t:mpfr_t', 'Input must be numeric, string, or mpfr_t.');
      end
    end

    function prec = prec (obj)
      % Return the precision of obj, i.e., the number of bits used to store
      % its significand.
      prec = mpfr_ ('get_prec', obj.idx);
    end

    function d = double (obj, rnd)
      if (nargin < 2)
        rnd = mpfr_ ('get_default_rounding_mode');
      end
      d = reshape (mpfr_ ('get_d', obj.idx, rnd), obj.dims(1), obj.dims(2));
    end

    % More information about class methods.
    % https://octave.org/doc/v6.2.0/Operator-Overloading.html
    % https://www.mathworks.com/help/matlab/matlab_oop/implementing-operators-for-your-class.html
    % https://www.mathworks.com/help/matlab/matlab_oop/methods-that-modify-default-behavior.html

    function disp (obj)
      % Object display
      if (prod (obj.dims) == 1)
        fprintf (1, '  MPFR scalar (precision %d binary digits)\n\n', obj.prec);
        fprintf (1, '    double approximation: %f\n', double (obj));
      else
        fprintf (1, '  %dx%d MPFR matrix\n\n', obj.dims(1), obj.dims(2));
      end
    end

    function c = plus (a, b)
      % Binary addition `a + b`
      % Precision of result is the maximum precision of a and b.
      % Using default rounding mode.
      if (isnumeric (a))
        c = plus (b, a);
      elseif (isa (a, 'mpfr_t') && isnumeric (b))
        if (isscalar (b) || isequal (a.dims, size (b)))
          prec = max (mpfr_ ('get_prec', a));
          cc = mpfr_t (zeros (a.dims), prec);
        else
          error ('mpfr_t:plus', 'Incompatible dimensions of a and b.');
        end
        mpfr_ ('add_d', cc, a, double (b(:)), ...
               mpfr_t.get_default_rounding_mode ());
        c = cc;  % Do not assign c before calculation succeeded!
      elseif (isa (a, 'mpfr_t') && isa (b, 'mpfr_t'))
        prec = max (max (mpfr_ ('get_prec', a)), max (mpfr_ ('get_prec', b)));
        if (isequal (a.dims, b.dims) || isequal (b.dims, [1 1]))
          cc = mpfr_t (zeros (a.dims), prec);
        elseif (isequal (a.dims, [1 1]))
          cc = mpfr_t (zeros (b.dims), prec);
        else
          error ('mpfr_t:plus', 'Incompatible dimensions of a and b.');
        end
        mpfr_ ('add', cc, a, b, mpfr_t.get_default_rounding_mode ());
        c = cc;  % Do not assign c before calculation succeeded!
      else
        error ('mpfr_t:plus', 'Invalid operands a and b.');
      end
    end

    function c = minus (a, b)
      % Binary subtraction `a - b`
      % Precision of result is the maximum precision of a and b.
      % Using default rounding mode.
      if (isnumeric (a) && isa (b, 'mpfr_t'))
        if (isscalar (a) || isequal (size (a), b.dims))
          prec = max (mpfr_ ('get_prec', b));
          cc = mpfr_t (zeros (b.dims), prec);
        else
          error ('mpfr_t:minus', 'Incompatible dimensions of a and b.');
        end
        mpfr_ ('d_sub', cc, double (a(:)), b, ...
               mpfr_t.get_default_rounding_mode ());
        c = cc;  % Do not assign c before calculation succeeded!
      elseif (isa (a, 'mpfr_t') && isnumeric (b))
        if (isscalar (b) || isequal (a.dims, size (b)))
          prec = max (mpfr_ ('get_prec', a));
          cc = mpfr_t (zeros (a.dims), prec);
        else
          error ('mpfr_t:minus', 'Incompatible dimensions of a and b.');
        end
        mpfr_ ('sub_d', cc, a, double (b(:)), ...
               mpfr_t.get_default_rounding_mode ());
        c = cc;  % Do not assign c before calculation succeeded!
      elseif (isa (a, 'mpfr_t') && isa (b, 'mpfr_t'))
        prec = max (max (mpfr_ ('get_prec', a)), max (mpfr_ ('get_prec', b)));
        if (isequal (a.dims, b.dims) || isequal (b.dims, [1 1]))
          cc = mpfr_t (zeros (a.dims), prec);
        elseif (isequal (a.dims, [1 1]))
          cc = mpfr_t (zeros (b.dims), prec);
        else
          error ('mpfr_t:minus', 'Incompatible dimensions of a and b.');
        end
        mpfr_ ('sub', cc, a, b, mpfr_t.get_default_rounding_mode ());
        c = cc;  % Do not assign c before calculation succeeded!
      else
        error ('mpfr_t:minus', 'Invalid operands a and b.');
      end
    end

%    function uminus(a)
%    % Unary minus `-a`
%    end

%    function uplus(a)
%    % Unary plus `+a`
%    end

    function c = times (a, b)
      % Element-wise multiplication `a .* b`
      % Precision of result is the maximum precision of a and b.
      % Using default rounding mode.
      if (isnumeric (a))
        c = times (b, a);
      elseif (isa (a, 'mpfr_t') && isnumeric (b))
        if (isscalar (b) || isequal (a.dims, size (b)))
          prec = max (mpfr_ ('get_prec', a));
          cc = mpfr_t (zeros (a.dims), prec);
        else
          error ('mpfr_t:times', 'Incompatible dimensions of a and b.');
        end
        mpfr_ ('mul_d', cc, a, double (b(:)), ...
               mpfr_t.get_default_rounding_mode ());
        c = cc;  % Do not assign c before calculation succeeded!
      elseif (isa (a, 'mpfr_t') && isa (b, 'mpfr_t'))
        prec = max (max (mpfr_ ('get_prec', a)), max (mpfr_ ('get_prec', b)));
        if (isequal (a.dims, b.dims) || isequal (b.dims, [1 1]))
          cc = mpfr_t (zeros (a.dims), prec);
        elseif (isequal (a.dims, [1 1]))
          cc = mpfr_t (zeros (b.dims), prec);
        else
          error ('mpfr_t:times', 'Incompatible dimensions of a and b.');
        end
        mpfr_ ('mul', cc, a, b, mpfr_t.get_default_rounding_mode ());
        c = cc;  % Do not assign c before calculation succeeded!
      else
        error ('mpfr_t:times', 'Invalid operands a and b.');
      end
    end

%    function mtimes(a,b)
%    % Matrix multiplication `a*b`
%    end

     function c = rdivide (a, b)
      % Right element-wise division `a ./ b`
      % Precision of result is the maximum precision of a and b.
      % Using default rounding mode.
      if (isnumeric (a) && isa (b, 'mpfr_t'))
        if (isscalar (a) || isequal (size (a), b.dims))
          prec = max (mpfr_ ('get_prec', b));
          cc = mpfr_t (zeros (b.dims), prec);
        else
          error ('mpfr_t:rdivide', 'Incompatible dimensions of a and b.');
        end
        mpfr_ ('d_div', cc, double (a(:)), b, ...
               mpfr_t.get_default_rounding_mode ());
        c = cc;  % Do not assign c before calculation succeeded!
      elseif (isa (a, 'mpfr_t') && isnumeric (b))
        if (isscalar (b) || isequal (a.dims, size (b)))
          prec = max (mpfr_ ('get_prec', a));
          cc = mpfr_t (zeros (a.dims), prec);
        else
          error ('mpfr_t:rdivide', 'Incompatible dimensions of a and b.');
        end
        mpfr_ ('div_d', cc, a, double (b(:)), ...
               mpfr_t.get_default_rounding_mode ());
        c = cc;  % Do not assign c before calculation succeeded!
      elseif (isa (a, 'mpfr_t') && isa (b, 'mpfr_t'))
        prec = max (max (mpfr_ ('get_prec', a)), max (mpfr_ ('get_prec', b)));
        if (isequal (a.dims, b.dims) || isequal (b.dims, [1 1]))
          cc = mpfr_t (zeros (a.dims), prec);
        elseif (isequal (a.dims, [1 1]))
          cc = mpfr_t (zeros (b.dims), prec);
        else
          error ('mpfr_t:rdivide', 'Incompatible dimensions of a and b.');
        end
        mpfr_ ('div', cc, a, b, mpfr_t.get_default_rounding_mode ());
        c = cc;  % Do not assign c before calculation succeeded!
      else
        error ('mpfr_t:rdivide', 'Invalid operands a and b.');
      end
    end

    function c = ldivide (a, b)
      % Left element-wise division `a .\ b`
      c = rdivide (b, a);
    end

%    function mrdivide(a,b)
%    % Matrix right division `a/b`
%    end

%    function mldivide(a,b)
%    % Matrix left division `a\b`
%    end

%    function power(a,b)
%    % Element-wise power `a.^b`
%    end

%    function mpower(a,b)
%    % Matrix power `a^b`
%    end

%    function lt(a,b)
%    % Less than `a < b`
%    end

%    function gt(a,b)
%    % Greater than `a > b`
%    end

%    function le(a,b)
%    % Less than or equal to `a <= b`
%    end

%    function ge(a,b)
%    % Greater than or equal to `a >= b`
%    end

%    function ne(a,b)
%    % Not equal to `a ~= b`
%    end

%    function eq(a,b)
%    % Equality `a == b`
%    end

%    function and(a,b)
%    % Logical AND `a & b`
%    end

%    function or(a,b)
%    % Logical OR `a | b`
%    end

%    function not(a)
%    % Logical NOT `~a`
%    end

%    function colon(a,d,b)
%    % Colon operator `a:d:b`
%    end

%    function colon(a,b)
%    % Colon operator `a:b`
%    end

%    function ctranspose(a)
%    % Complex conjugate transpose `a'`
%    end

%    function transpose(a)
%    % Matrix transpose a.'`
%    end

%    function horzcat(a,b,...)
%    % Horizontal concatenation `[a b]`
%    end

%    function vertcat(a,b,...)
%    % Vertical concatenation `[a; b]`
%    end

%    function subsref(a,s)
%    % Subscripted reference `a(s1,s2,...sn)`
%    end

%    function subsasgn(a,s,b)
%    % Subscripted assignment `a(s1,...,sn) = b`
%    end

%    function subsindex(a)
%    % Subscript index `b(a)`
%    end

  end

end
