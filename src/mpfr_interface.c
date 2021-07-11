#include "mpfr_interface.h"

/**
 * Octave/Matlab MEX interface for MPFR (Version 4.1.0).
 *
 * https://www.mpfr.org/mpfr-current/mpfr.html
 *
 * See mpfr_interface.m for documentation.
 */

void
mexFunction (int nlhs, mxArray *plhs[],
             int nrhs, const mxArray *prhs[])
{
  // Check for sufficient input parameters
  if ((nrhs < 1) || ! mxIsChar (prhs[0])) {
    mexErrMsgIdAndTxt ("mp:mexFunction", "First input must be a string.");
  }
  // Read command to execute.
  size_t buf_len = (mxGetM (prhs[0]) * mxGetN (prhs[0])) + 1;
  char *cmd_buf = mxCalloc (buf_len, sizeof (char));
  cmd_buf = mxArrayToString(prhs[0]);

  // Marker if error should be thrown.
  int throw_error = 0;

  // Index vector for MPFR variables.
  size_t* idx_vec = NULL;
  DBG_PRINTF ("Command: [%d] = %s(%d)\n", nlhs, cmd_buf, nrhs);
  do
    {
      /*
      ========================
      == Non-MPFR functions ==
      ========================
      */


      /**
       * size_t get_data_capacity (void)
       *
       * MPFR memory management helper function.
       */
      if (strcmp (cmd_buf, "get_data_capacity") == 0)
        {
          if (nrhs != 1)
            {
              MEX_FCN_ERR ("%s: Invalid number of arguments.\n", cmd_buf);
              break;
            }
          plhs[0] = mxCreateDoubleScalar ((double) data_capacity);
        }

      /**
       * size_t get_data_size (void)
       *
       * MPFR memory management helper function.
       */
      else if (strcmp (cmd_buf, "get_data_size") == 0)
        {
          if (nrhs != 1)
            {
              MEX_FCN_ERR ("%s: Invalid number of arguments.\n", cmd_buf);
              break;
            }
          plhs[0] = mxCreateDoubleScalar ((double) data_size);
        }

      /**
       * void set_verbose (int level)
       *
       *   0 print no MEX_FCN_ERR to stdout
       *   1 print    MEX_FCN_ERR to stdout
       */
      else if (strcmp (cmd_buf, "set_verbose") == 0)
        {
          if (nrhs != 2)
            {
              MEX_FCN_ERR ("%s: Invalid number of arguments.\n", cmd_buf);
              break;
            }
          int64_t level = 1;
          if (extract_si (1, nrhs, prhs, &level)
              && ((level == 0) || (level == 1)))
            VERBOSE = (int) level;
          else
            MEX_FCN_ERR ("%s: VERBOSE must be 0 or 1.\n", cmd_buf);
        }

      /**
       * idx_t mex_mpfr_allocate (size_t count)
       *
       * Allocate memory for `count` new MPFR variables and initialize them to
       * default precision.
       *
       * Returns the start and end index (1-based) of the internally newly
       * created MPFR variables.
       */
      else if (strcmp (cmd_buf, "allocate") == 0)
        {
          if (nrhs != 2)
            {
              MEX_FCN_ERR ("%s: Invalid number of arguments.\n", cmd_buf);
              break;
            }
          size_t count = 0;
          if (! extract_ui (1, nrhs, prhs, &count))
            {
              MEX_FCN_ERR ("%s: Count must be a positive numeric scalar.\n",
                           cmd_buf);
              break;
            }

          DBG_PRINTF ("allocate '%d' new MPFR variables\n", count);
          idx_t idx;
          if (! mex_mpfr_allocate (count, &idx))
            {
              MEX_FCN_ERR ("%s\n", "Memory allocation failed.");
              break;
            }
          // Return start and end indices (1-based).
          plhs[0] = mxCreateNumericMatrix (2, 1, mxDOUBLE_CLASS, mxREAL);
          double* ptr = mxGetPr (plhs[0]);
          ptr[0] = (double) idx.start;
          ptr[1] = (double) idx.end;
        }


      /*
      ====================
      == MPFR functions ==
      ====================
      */


      /**
       * mpfr_prec_t mpfr_get_default_prec (void)
       *
       * Return the current default MPFR precision in bits.  See the
       * documentation of mpfr_set_default_prec.
       */
      else if (strcmp (cmd_buf, "get_default_prec") == 0)
        {
          if (nrhs != 1)
            {
              MEX_FCN_ERR ("%s: Invalid number of arguments.\n", cmd_buf);
              break;
            }
          plhs[0] = mxCreateDoubleScalar ((double) mpfr_get_default_prec ());
        }

      /**
       * void mpfr_set_default_prec (mpfr_prec_t prec)
       *
       * Set the default precision to be exactly prec bits, where prec can be
       * any integer between MPFR_PREC_MIN and MPFR_PREC_MAX.  The precision of
       * a variable means the number of bits used to store its significand. All
       * subsequent calls to mpfr_init or mpfr_inits will use this precision,
       * but previously initialized variables are unaffected.  The default
       * precision is set to 53 bits initially.
       */
      else if (strcmp (cmd_buf, "set_default_prec") == 0)
        {
          if (nrhs != 2)
            {
              MEX_FCN_ERR ("%s: Invalid number of arguments.\n", cmd_buf);
              break;
            }
          mpfr_prec_t prec = mpfr_get_default_prec ();
          if (extract_prec (1, nrhs, prhs, &prec))
            mpfr_set_default_prec (prec);
          else
            MEX_FCN_ERR ("%s: Precision must be a numeric scalar between "
                         "%ld and %ld.\n", cmd_buf, MPFR_PREC_MIN,
                         MPFR_PREC_MAX);
        }

      /**
       * mpfr_rnd_t mpfr_get_default_rounding_mode (void)
       *
       * Get the default rounding mode.
       */
      else if (strcmp (cmd_buf, "get_default_rounding_mode") == 0)
        {
          if (nrhs != 1)
            {
              MEX_FCN_ERR ("%s: Invalid number of arguments.\n", cmd_buf);
              break;
            }
          plhs[0] = mxCreateDoubleScalar (export_rounding_mode (
            mpfr_get_default_rounding_mode ()));
        }

      /**
       * void mpfr_set_default_rounding_mode (mpfr_rnd_t rnd)
       *
       * Set the default rounding mode to rnd.  The default rounding mode is
       * to nearest initially.
       */
      else if (strcmp (cmd_buf, "set_default_rounding_mode") == 0)
        {
          if (nrhs != 2)
            {
              MEX_FCN_ERR ("%s: Invalid number of arguments.\n", cmd_buf);
              break;
            }
          mpfr_rnd_t rnd = mpfr_get_default_rounding_mode ();
          if (extract_rounding_mode (1, nrhs, prhs, &rnd))
            mpfr_set_default_rounding_mode (rnd);
          else
            MEX_FCN_ERR ("%s: Rounding must be a numeric scalar between "
                         "-1 and 3.\n", cmd_buf);
        }

      /**
       * mpfr_prec_t mpfr_get_prec (mpfr_t x)
       *
       * Return the precision of x, i.e., the number of bits used to store its
       * significand.
       */
      else if (strcmp (cmd_buf, "get_prec") == 0)
        {
          if (nrhs != 2)
            {
              MEX_FCN_ERR ("%s: Invalid number of arguments.\n", cmd_buf);
              break;
            }
          idx_t idx;
          if (! extract_idx (1, nrhs, prhs, &idx))
            {
              MEX_FCN_ERR ("%s: Invalid MPFR variable indices.\n", cmd_buf);
              break;
            }

          DBG_PRINTF ("get_prec [%d:%d]\n", idx.start, idx.end);
          plhs[0] = mxCreateNumericMatrix (length (&idx), 1, mxDOUBLE_CLASS,
                                           mxREAL);
          double* plhs_0_pr = mxGetPr (plhs[0]);
          for (size_t i = 0; i < length (&idx); i++)
            plhs_0_pr[i] = (double) mpfr_get_prec (&data[(idx.start - 1) + i]);
        }

      /**
       * void mpfr_set_prec (mpfr_t x, mpfr_prec_t prec)
       *
       * Set the precision of x to be exactly prec bits, and set its value to
       * NaN.  The previous value stored in x is lost.  It is equivalent to a
       * call to mpfr_clear(x) followed by a call to mpfr_init2(x, prec), but
       * more efficient as no allocation is done in case the current allocated
       * space for the significand of x is enough.  The precision prec can be
       * any integer between MPFR_PREC_MIN and MPFR_PREC_MAX.  In case you
       * want to keep the previous value stored in x, use mpfr_prec_round
       * instead.
       *
       * Warning! You must not use this function if x was initialized with
       * MPFR_DECL_INIT or with mpfr_custom_init_set (see Custom Interface).
       *
       *
       * void mpfr_init2 (mpfr_t x, mpfr_prec_t prec)
       *
       * Initialize x, set its precision to be exactly prec bits and its value
       * to NaN. (Warning: the corresponding MPF function initializes to zero
       * instead.)
       *
       * Normally, a variable should be initialized once only or at least be
       * cleared, using mpfr_clear, between initializations.  To change the
       * precision of a variable that has already been initialized, use
       * mpfr_set_prec or mpfr_prec_round; note that if the precision is
       * decreased, the unused memory will not be freed, so that it may be
       * wise to choose a large enough initial precision in order to avoid
       * reallocations. The precision prec must be an integer between
       * MPFR_PREC_MIN and MPFR_PREC_MAX (otherwise the behavior is undefined).
       */
      else if ((strcmp (cmd_buf, "set_prec") == 0)
               || (strcmp (cmd_buf, "init2") == 0))
        {
          // Note combined, as due to this MEX interface, there are no
          // uninitialized MPFR variables.
          if (nrhs != 3)
            {
              MEX_FCN_ERR ("%s: Invalid number of arguments.\n", cmd_buf);
              break;
            }
          idx_t idx;
          if (! extract_idx (1, nrhs, prhs, &idx))
            {
              MEX_FCN_ERR ("%s: Invalid MPFR variable indices.\n", cmd_buf);
              break;
            }
          mpfr_prec_t prec = mpfr_get_default_prec ();
          if (! extract_prec (2, nrhs, prhs, &prec))
            {
              MEX_FCN_ERR ("%s: Precision must be a numeric scalar between "
                           "%ld and %ld.\n", cmd_buf, MPFR_PREC_MIN,
                          MPFR_PREC_MAX);
              break;
            }

          DBG_PRINTF ("%s: [%d:%d] (prec = %d)\n",
                      cmd_buf, idx.start, idx.end, (int) prec);
          for (size_t i = 0; i < length (&idx); i++)
            mpfr_set_prec (&data[(idx.start - 1) + i], prec);
        }

      /**
       * double mpfr_get_d (mpfr_t op, mpfr_rnd_t rnd)
       *
       * Convert op to a float (respectively double, long double, _Decimal64,
       * or _Decimal128) using the rounding mode rnd.
       * If op is NaN, some fixed NaN (either quiet or signaling) or the result
       * of 0.0/0.0 is returned.
       * If op is ±Inf, an infinity of the same sign or the result of ±1.0/0.0
       * is returned.
       * If op is zero, these functions return a zero, trying to preserve its
       * sign, if possible.
       * The mpfr_get_float128, mpfr_get_decimal64 and mpfr_get_decimal128
       * functions are built only under some conditions: see the documentation
       * of mpfr_set_float128, mpfr_set_decimal64 and mpfr_set_decimal128
       * respectively.
       */
      else if (strcmp (cmd_buf, "get_d") == 0)
        {
          if (nrhs != 3)
            {
              MEX_FCN_ERR ("%s: Invalid number of arguments.\n", cmd_buf);
              break;
            }
          idx_t idx;
          if (! extract_idx (1, nrhs, prhs, &idx))
            {
              MEX_FCN_ERR ("%s: Invalid MPFR variable indices.\n", cmd_buf);
              break;
            }
          mpfr_rnd_t rnd = mpfr_get_default_rounding_mode ();
          if (! extract_rounding_mode (2, nrhs, prhs, &rnd))
            {
              MEX_FCN_ERR ("%s: Rounding must be a numeric scalar between "
                           "-1 and 3.\n", cmd_buf);
              break;
            }

          DBG_PRINTF ("get_d [%d:%d]\n", idx.start, idx.end);
          plhs[0] = mxCreateNumericMatrix (length (&idx), 1, mxDOUBLE_CLASS,
                                           mxREAL);
          double* plhs_0_pr = mxGetPr (plhs[0]);
          for (size_t i = 0; i < length (&idx); i++)
            plhs_0_pr[i] = mpfr_get_d (&data[(idx.start - 1) + i], rnd);
        }

      /**
       * int mpfr_set_d (mpfr_t rop, double op, mpfr_rnd_t rnd)
       *
       * Set the value of rop from op, rounded toward the given direction rnd.
       * Note that the input 0 is converted to +0 by mpfr_set_ui, mpfr_set_si,
       * mpfr_set_uj, mpfr_set_sj, The mpfr_set_float128 function is built
       * only with the configure option ‘--enable-float128’, which requires
       * the compiler or system provides the ‘_Float128’ data type (GCC 4.3
       * or later supports this data type); to use mpfr_set_float128, one
       * should define the macro MPFR_WANT_FLOAT128 before including mpfr.h.
       * mpfr_set_z, mpfr_set_q and mpfr_set_f, regardless of the rounding mode.
       * If the system does not support the IEEE 754 standard, mpfr_set_flt,
       * mpfr_set_d, mpfr_set_ld, mpfr_set_decimal64 and mpfr_set_decimal128
       * might not preserve the signed zeros. The mpfr_set_decimal64 and
       * mpfr_set_decimal128 functions are built only with the configure
       * option ‘--enable-decimal-float’, and when the compiler or system
       * provides the ‘_Decimal64’ and ‘_Decimal128’ data type; to use those
       * functions, one should define the macro MPFR_WANT_DECIMAL_FLOATS
       * before including mpfr.h. mpfr_set_q might fail if the numerator
       * (or the denominator) cannot be represented as a mpfr_t.
       *
       * For mpfr_set, the sign of a NaN is propagated in order to mimic the
       * IEEE 754 copy operation.  But contrary to IEEE 754, the NaN flag is
       * set as usual.
       *
       * Note: If you want to store a floating-point constant to a mpfr_t,
       * you should use mpfr_set_str (or one of the MPFR constant functions,
       * such as mpfr_const_pi for Pi) instead of mpfr_set_flt, mpfr_set_d,
       * mpfr_set_ld, mpfr_set_decimal64 or mpfr_set_decimal128.  Otherwise
       * the floating-point constant will be first converted into a reduced-
       * precision (e.g., 53-bit) binary (or decimal, for mpfr_set_decimal64
       * and mpfr_set_decimal128) number before MPFR can work with it.
       */
      else if (strcmp (cmd_buf, "set_d") == 0)
        {
          if (nrhs != 4)
            {
              MEX_FCN_ERR ("%s: Invalid number of arguments.\n", cmd_buf);
              break;
            }
          idx_t idx;
          if (! extract_idx (1, nrhs, prhs, &idx))
            {
              MEX_FCN_ERR ("%s: Invalid MPFR variable indices.\n", cmd_buf);
              break;
            }
          if (! mxIsDouble (prhs[2])
              || ((mxGetM (prhs[2]) * mxGetN (prhs[2])) != length (&idx)))
            {
              MEX_FCN_ERR ("%s: Invalid number of double values.\n", cmd_buf);
              break;
            }
          double* op_pr = mxGetPr (prhs[2]);
          mpfr_rnd_t rnd = mpfr_get_default_rounding_mode ();
          if (! extract_rounding_mode (3, nrhs, prhs, &rnd))
            {
              MEX_FCN_ERR ("%s: Rounding must be a numeric scalar between "
                           "-1 and 3.\n", cmd_buf);
              break;
            }

          DBG_PRINTF ("set_d [%d:%d]\n", idx.start, idx.end);
          for (size_t i = 0; i < length (&idx); i++)
            mpfr_set_d (&data[(idx.start - 1) + i], op_pr[i], rnd);
        }

      /**
       * int mpfr_add (mpfr_t rop, mpfr_t op1, mpfr_t op2, mpfr_rnd_t rnd)
       *
       * Set rop to op1 + op2 rounded in the direction rnd.  The IEEE 754
       * rules are used, in particular for signed zeros.  But for types having
       * no signed zeros, 0 is considered unsigned (i.e., (+0) + 0 = (+0) and
       * (-0) + 0 = (-0)).  The mpfr_add_d function assumes that the radix of
       * the double type is a power of 2, with a precision at most that
       * declared by the C implementation (macro IEEE_DBL_MANT_DIG, and if not
       * defined 53 bits).
       *
       *
       * int mpfr_sub (mpfr_t rop, mpfr_t op1, mpfr_t op2, mpfr_rnd_t rnd)
       *
       * Set rop to op1 - op2 rounded in the direction rnd.  The IEEE 754
       * rules are used, in particular for signed zeros. But for types having
       * no signed zeros, 0 is considered unsigned (i.e., (+0) - 0 = (+0),
       * (-0) - 0 = (-0), 0 - (+0) = (-0) and 0 - (-0) = (+0)).  The same
       * restrictions than for mpfr_add_d apply to mpfr_d_sub and mpfr_sub_d.
       *
       *
       * int mpfr_mul (mpfr_t rop, mpfr_t op1, mpfr_t op2, mpfr_rnd_t rnd)
       *
       * Set rop to op1 times op2 rounded in the direction rnd.  When a result
       * is zero, its sign is the product of the signs of the operands (for
       * types having no signed zeros, 0 is considered positive).  The same
       * restrictions than for mpfr_add_d apply to mpfr_mul_d.
       *
       *
       * int mpfr_div (mpfr_t rop, mpfr_t op1, mpfr_t op2, mpfr_rnd_t rnd)
       *
       * Set rop to op1/op2 rounded in the direction rnd.  When a result is
       * zero, its sign is the product of the signs of the operands.  For
       * types having no signed zeros, 0 is considered positive; but note that
       * if op1 is non-zero and op2 is zero, the result might change from ±Inf
       * to NaN in future MPFR versions if there is an opposite decision on
       * the IEEE 754 side. The same restrictions than for mpfr_add_d apply
       * to mpfr_d_div and mpfr_div_d.
       */
      else if ((strcmp (cmd_buf, "add") == 0)
               || (strcmp (cmd_buf, "sub") == 0)
               || (strcmp (cmd_buf, "mul") == 0)
               || (strcmp (cmd_buf, "div") == 0))
        {
          if (nrhs != 5)
            {
              MEX_FCN_ERR ("%s: Invalid number of arguments.\n", cmd_buf);
              break;
            }
          idx_t rop;
          if (! extract_idx (1, nrhs, prhs, &rop))
            {
              MEX_FCN_ERR ("%s:rop Invalid MPFR variable indices.\n", cmd_buf);
              break;
            }
          idx_t op1;
          if (! extract_idx (2, nrhs, prhs, &op1))
            {
              MEX_FCN_ERR ("%s:op1 Invalid MPFR variable indices.\n", cmd_buf);
              break;
            }
          idx_t op2;
          if (! extract_idx (3, nrhs, prhs, &op2))
            {
              MEX_FCN_ERR ("%s:op2 Invalid MPFR variable indices.\n", cmd_buf);
              break;
            }
          mpfr_rnd_t rnd = mpfr_get_default_rounding_mode ();
          if (! extract_rounding_mode (4, nrhs, prhs, &rnd))
            {
              MEX_FCN_ERR ("%s: Rounding must be a numeric scalar between "
                           "-1 and 3.\n", cmd_buf);
              break;
            }

          DBG_PRINTF ("%s [%d:%d] = [%d:%d] + [%d:%d] (rnd = %d)\n", cmd_buf,
                      rop.start, rop.end, op1.start, op1.end,
                      op2.start, op2.end, (int) rnd);

          int (*operator) (mpfr_t, const mpfr_t, const mpfr_t, mpfr_rnd_t);
          if (strcmp (cmd_buf, "add") == 0)
            operator = mpfr_add;
          else if (strcmp (cmd_buf, "sub") == 0)
            operator = mpfr_sub;
          else if (strcmp (cmd_buf, "mul") == 0)
            operator = mpfr_mul;
          else if (strcmp (cmd_buf, "div") == 0)
            operator = mpfr_div;
          else
            {
              MEX_FCN_ERR ("%s: Bad operator.\n", cmd_buf);
              break;
            }

          if ((length (&rop) == length (&op1))
              && (length (&rop) == length (&op2)))
            {
              for (size_t i = 0; i < length (&rop); i++)
                operator (&data[(rop.start - 1) + i],
                          &data[(op1.start - 1) + i],
                          &data[(op2.start - 1) + i], rnd);
            }
          else if ((length (&rop) == length (&op1)) && (length (&op2) == 1))
            {
              for (size_t i = 0; i < length (&rop); i++)
                operator (&data[(rop.start - 1) + i],
                          &data[(op1.start - 1) + i],
                          &data[(op2.start - 1)], rnd);
            }
          else if ((length (&rop) == length (&op2)) && (length (&op1) == 1))
            {
              for (size_t i = 0; i < length (&rop); i++)
                operator (&data[(rop.start - 1) + i],
                          &data[(op1.start - 1)],
                          &data[(op2.start - 1) + i], rnd);
            }
          else
            {
              MEX_FCN_ERR ("%s: Bad operand dimensions.\n", cmd_buf);
              break;
            }
        }

      /**
       * int mpfr_add_d (mpfr_t rop, mpfr_t op1, double op2, mpfr_rnd_t rnd)
       * int mpfr_sub_d (mpfr_t rop, mpfr_t op1, double op2, mpfr_rnd_t rnd)
       * int mpfr_mul_d (mpfr_t rop, mpfr_t op1, double op2, mpfr_rnd_t rnd)
       * int mpfr_div_d (mpfr_t rop, mpfr_t op1, double op2, mpfr_rnd_t rnd)
       *
       * See help text for add, sub, etc. above.
       */
      else if ((strcmp (cmd_buf, "add_d") == 0)
               || (strcmp (cmd_buf, "sub_d") == 0)
               || (strcmp (cmd_buf, "mul_d") == 0)
               || (strcmp (cmd_buf, "div_d") == 0))
        {
          if (nrhs != 5)
            {
              MEX_FCN_ERR ("%s: Invalid number of arguments.\n", cmd_buf);
              break;
            }
          idx_t rop;
          if (! extract_idx (1, nrhs, prhs, &rop))
            {
              MEX_FCN_ERR ("%s:rop Invalid MPFR variable indices.\n", cmd_buf);
              break;
            }
          idx_t op1;
          if (! extract_idx (2, nrhs, prhs, &op1)
              || (length (&rop) != length (&op1)))
            {
              MEX_FCN_ERR ("%s:op1 Invalid MPFR variable indices.\n", cmd_buf);
              break;
            }
          if (! mxIsDouble (prhs[2]))
            {
              MEX_FCN_ERR ("%s:op2 Invalid.\n", cmd_buf);
              break;
            }
          double op2 = 0.0;
          double* op2_pr = NULL;
          if (! extract_d (3, nrhs, prhs, &op2))
            {
              if ((mxGetM (prhs[3]) * mxGetN (prhs[3])) != length (&rop))
                {
                  MEX_FCN_ERR ("%s:op2 Bad dimensions.\n", cmd_buf);
                  break;
                }
              else
                op2_pr = mxGetPr (prhs[3]);
            }
          mpfr_rnd_t rnd = mpfr_get_default_rounding_mode ();
          if (! extract_rounding_mode (4, nrhs, prhs, &rnd))
            {
              MEX_FCN_ERR ("%s: Rounding must be a numeric scalar between "
                           "-1 and 3.\n", cmd_buf);
              break;
            }

          DBG_PRINTF ("%s [%d:%d] = [%d:%d] + [%d:%d] (rnd = %d)\n", cmd_buf,
                      rop.start, rop.end, op1.start, op1.end,
                      mxGetM (prhs[3]), mxGetN (prhs[3]), (int) rnd);

          int (*operator) (mpfr_t, const mpfr_t, const double, mpfr_rnd_t);
          if (strcmp (cmd_buf, "add_d") == 0)
            operator = mpfr_add_d;
          else if (strcmp (cmd_buf, "sub_d") == 0)
            operator = mpfr_sub_d;
          else if (strcmp (cmd_buf, "mul_d") == 0)
            operator = mpfr_mul_d;
          else if (strcmp (cmd_buf, "div_d") == 0)
            operator = mpfr_div_d;
          else
            {
              MEX_FCN_ERR ("%s: Bad operator.\n", cmd_buf);
              break;
            }

          if (op2_pr != NULL)
            {
              for (size_t i = 0; i < length (&rop); i++)
                operator (&data[(rop.start - 1) + i],
                          &data[(op1.start - 1) + i], op2_pr[i], rnd);
            }
          else
            {
              for (size_t i = 0; i < length (&rop); i++)
                operator (&data[(rop.start - 1) + i],
                          &data[(op1.start - 1) + i], op2, rnd);
            }
        }

      /**
       * int mpfr_d_sub (mpfr_t rop, double op1, mpfr_t op2, mpfr_rnd_t rnd)
       * int mpfr_d_div (mpfr_t rop, double op1, mpfr_t op2, mpfr_rnd_t rnd)
       *
       * See help text for add, sub, etc. above.
       */
      else if ((strcmp (cmd_buf, "d_sub") == 0)
               || (strcmp (cmd_buf, "d_div") == 0))
        {
          if (nrhs != 5)
            {
              MEX_FCN_ERR ("%s: Invalid number of arguments.\n", cmd_buf);
              break;
            }
          idx_t rop;
          if (! extract_idx (1, nrhs, prhs, &rop))
            {
              MEX_FCN_ERR ("%s:rop Invalid MPFR variable indices.\n", cmd_buf);
              break;
            }
          if (! mxIsDouble (prhs[2]))
            {
              MEX_FCN_ERR ("%s:op1 Invalid.\n", cmd_buf);
              break;
            }
          double op1 = 0.0;
          double* op1_pr = NULL;
          if (! extract_d (2, nrhs, prhs, &op1))
            {
              if ((mxGetM (prhs[2]) * mxGetN (prhs[2])) != length (&rop))
                {
                  MEX_FCN_ERR ("%s:op1 Bad dimensions.\n", cmd_buf);
                  break;
                }
              else
                op1_pr = mxGetPr (prhs[2]);
            }
          idx_t op2;
          if (! extract_idx (3, nrhs, prhs, &op2)
              || (length (&rop) != length (&op2)))
            {
              MEX_FCN_ERR ("%s:op1 Invalid MPFR variable indices.\n", cmd_buf);
              break;
            }
          mpfr_rnd_t rnd = mpfr_get_default_rounding_mode ();
          if (! extract_rounding_mode (4, nrhs, prhs, &rnd))
            {
              MEX_FCN_ERR ("%s: Rounding must be a numeric scalar between "
                           "-1 and 3.\n", cmd_buf);
              break;
            }

          DBG_PRINTF ("%s [%d:%d] = [%d:%d] + [%d:%d] (rnd = %d)\n", cmd_buf,
                      rop.start, rop.end, mxGetM (prhs[2]), mxGetN (prhs[2]),
                      op2.start, op2.end, (int) rnd);

          int (*operator) (mpfr_t, const double, const mpfr_t, mpfr_rnd_t);
          if (strcmp (cmd_buf, "d_sub") == 0)
            operator = mpfr_d_sub;
          else if (strcmp (cmd_buf, "d_div") == 0)
            operator = mpfr_d_div;
          else
            {
              MEX_FCN_ERR ("%s: Bad operator.\n", cmd_buf);
              break;
            }

          if (op1_pr != NULL)
            {
              for (size_t i = 0; i < length (&rop); i++)
                operator (&data[(rop.start - 1) + i], op1_pr[i],
                          &data[(op2.start - 1) + i], rnd);
            }
          else
            {
              for (size_t i = 0; i < length (&rop); i++)
                operator (&data[(rop.start - 1) + i], op1,
                          &data[(op2.start - 1) + i], rnd);
            }
        }

      else
        MEX_FCN_ERR ("Unknown command '%s'\n", cmd_buf);
    }
  while (0);

  // Tidy up.
  mxFree (cmd_buf);

  if (idx_vec != NULL)
    mxFree (idx_vec);

  if (throw_error)
    mexErrMsgIdAndTxt ("mp:mexFunction", "See previous error message.");
}
