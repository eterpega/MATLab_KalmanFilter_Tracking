classdef UnscentedKalmanFilterX < KalmanFilterX
% UnscentedKalmanFilterX class
%
% Summary of UnscentedKalmanFilterX:
% This is a class implementation of an Unscented Kalman Filter.
%
% UnscentedKalmanFilterX Properties: (*)
%   - StateMean         A (xDim x 1) vector used to store the last computed/set filtered state mean  
%   - StateCovar        A (xDim x xDim) matrix used to store the last computed/set filtered state covariance
%   - PredStateMean     A (xDim x 1) vector used to store the last computed prediicted state mean  
%   - PredStateCovar    A (xDim x xDim) matrix used to store the last computed/set predicted state covariance
%   - PredMeasMean      A (yDim x 1) vector used to store the last computed predicted measurement mean
%   - InnovErrCovar     A (yDim x yDim) matrix used to store the last computed innovation error covariance
%   - CrossCovar        A (xDim x yDim) matrix used to store the last computed cross-covariance Cov(X,Y)
%   - KalmanGain        A (xDim x yDim) matrix used to store the last computed Kalman gain%   
%   - Measurement       A (yDim x 1) matrix used to store the received measurement
%   - ControlInput      A (uDim x 1) matrix used to store the last received control input
%   - Alpha             ||
%   - Kappa             || UKF scaling parameters, as described in [1]
%   - Beta              || 
%   - Model             An object handle to StateSpaceModelX object
%       - Dyn = Object handle to DynamicModelX SubClass     | (TO DO: LinearGaussDynModelX) 
%       - Obs = Object handle to ObservationModelX SubClass | (TO DO: LinearGaussObsModelX)
%       - Ctr = Object handle to ControlModelX SubClass     | (TO DO: LinearCtrModelX)
%
%   (*) xDim, yDim and uDim denote the dimentionality of the state, measurement
%       and control vectors respectively.
%
% UnscentedKalmanFilterX Methods:
%    UnscentedKalmanFilterX  - Constructor method
%    predict        - Performs UKF prediction step
%    update         - Performs UKF update step
%    smooth         - Performs UKF smoothing on a provided set of estimates
%
% [1] E. A. Wan and R. Van Der Merwe, "The unscented Kalman filter for nonlinear estimation," 
%     Proceedings of the IEEE 2000 Adaptive Systems for Signal Processing, Communications, and 
%     Control Symposium (Cat. No.00EX373), Lake Louise, Alta., 2000, pp. 153-158.
% 
% See also DynamicModelX, ObservationModelX and ControlModelX template classes
  
    properties
        Alpha = 0.5
        Kappa = 0
        Beta  = 2
    end
    
    methods
        function this = UnscentedKalmanFilterX(varargin)
        % UNSCENTEDKALMANFILTER Constructor method
        %   
        % DESCRIPTION: 
        % * ukf = UnscentedKalmanFilterX() returns an unconfigured object 
        %   handle. Note that the object will need to be configured at a 
        %   later instance before any call is made to it's methods.
        % * ukf = UnscentedKalmanFilterX(ssm) returns an object handle,
        %   preconfigured with the provided StateSpaceModelX object handle ssm.
        % * ukf = UnscentedKalmanFilterX(ssm,priorStateMean,priorStateCov) 
        %   returns an object handle, preconfigured with the provided  
        %   StateSpaceModel object handle ssm and the prior information   
        %   about the state, provided in the form of the prorStateMean 
        %   and priorStateCov variables.
        % * ukf = UnscentedKalmanFilterX(___,Name,Value,___) instantiates an  
        %   object handle, configured with the options specified by one or 
        %   more Name,Value pair arguments. Alpha, Kappa and Beta values can
        %   only be passed this way. Default values are Alpha = 0.5, Kappa = 0 
        %   and Beta = 2. 
        %  See also predict, update, smooth. 
                 
            % Call SuperClass method
            this@KalmanFilterX(varargin{:});
            
            tmpIndex = 0;
            for i = 1:nargin
                if(~ischar(varargin{i}))
                    tmpIndex = tmpIndex + 1;
                end
            end
            
            if(tmpIndex<nargin)
                % Otherwise, fall back to input parser
                parser = inputParser;
                parser.KeepUnmatched = true;
                parser.addParameter('Alpha',NaN);
                parser.addParameter('Kappa',NaN);
                parser.addParameter('Beta',NaN);
                parser.parse(varargin{:});

                if(~isnan(parser.Results.Alpha))
                    this.Alpha = parser.Results.Alpha;
                end

                if(~isnan(parser.Results.Kappa))
                    this.Kappa = parser.Results.Kappa;
                end

                if(~isnan(parser.Results.Beta))
                    this.Beta = parser.Results.Beta;
                end
            end
        end
        
        function initialise(this,varargin)
        % INITIALISE Initialise the Extended KalmanFilter with a certain 
        % set of parameters. 
        %   
        % DESCRIPTION: 
        % * initialise(ekf, ssm) initialises the ExtendedKalmanFilterX object 
        %   ekf with the provided StateSpaceModelX object ssm.
        % * initialise(ekf,ssm,priorStateMean,priorStateCov) initialises 
        %   the ExtendedKalmanFilterX object kf with the provided StateSpaceModelX 
        %   object ssm and the prior information about the state, provided  
        %   in the form of the prorStateMean and priorStateCov variables.
        % * initialise(ekf,___,Name,Value,___) initialises the ExtendedKalmanFilterX 
        %   object kf with the options specified by one or more Name,Value 
        %   pair arguments. 
        %
        %  See also predict, update, smooth.   
           
            initialise@KalmanFilterX(this,varargin{:});
            
            % Otherwise, fall back to input parser
            parser = inputParser;
            parser.KeepUnmatched = true;
            parser.addParameter('Alpha',NaN);
            parser.addParameter('Kappa',NaN);
            parser.addParameter('Beta',NaN);
            parser.parse(varargin{:});
            
            if(~isnan(parser.Results.Alpha))
                this.Alpha = parser.Results.Alpha;
            end
            
            if(~isnan(parser.Results.Kappa))
                this.Kappa = parser.Results.Kappa;
            end
            
            if(~isnan(parser.Results.Beta))
                this.Beta = parser.Results.Beta;
            end
        end
        
        function predict(this)
        % PREDICT Perform an Unscented Kalman Filter prediction step
        %   
        % DESCRIPTION: 
        % * predict(this) calculates the predicted system state and measurement,
        %   as well as their associated uncertainty covariances.
        %
        % MORE DETAILS:
        % * UnscentedKalmanFilterX() uses the Model class property, which should be an
        %   instance/sublclass of the TrackingX.Models.StateSpaceModel class, in order
        %   to extract information regarding the underlying state-space model.
        % * State prediction is performed using the Model.Dyn property,
        %   which must be a subclass of TrackingX.Abstract.DynamicModel and
        %   provide the following interface functions:
        %   - Model.Dyn.feval(): Returns the model transition matrix
        %   - Model.Dyn.covariance(): Returns the process noise covariance
        % * Measurement prediction and innovation covariance calculation is
        %   performed using the Model.Obs class property, which should be
        %   a subclass of TrackingX.Abstract.DynamicModel and provide the
        %   following interface functions:
        %   - Model.Obs.heval(): Returns the model measurement matrix
        %   - Model.Obs.covariance(): Returns the measurement noise covariance
        %
        %  See also update, smooth.
        
             % Extract model parameters
            f = @(x) this.Model.Dyn.feval(x);
            Q = this.Model.Dyn.covariance();
            h = @(x) this.Model.Obs.heval(x);
            R = this.Model.Obs.covariance();
            if(~isempty(this.Model.Ctr))
                b   = @(x) this.Model.Ctr.beval(x);
                Qu  = this.Model.Ctr.covariance();
            else
                this.ControlInput   = 0;
                b   = @(x) 0;
                Qu  = 0;
            end
            
            % Perform prediction
            [this.PredStateMean, this.PredStateCovar, this.PredMeasMean,...
             this.InnovErrCovar, this.CrossCovar] = ...
                UnscentedKalmanFilterX_Predict(this.Alpha, this.Kappa, this.Beta,...
                                               this.StateMean, this.StateCovar,...
                                               f, Q, h, R, this.ControlInput, b, Qu);          
        end
        
        function update(this)
        % UPDATE Perform Extended Kalman Filter update step
        %   
        % DESCRIPTION: 
        % * update(this) calculates the corrected sytem state and the 
        %   associated uncertainty covariance.
        %
        %   See also KalmanFilterX, predict, iterate, smooth.
        
            % Call SuperClass method
            update@KalmanFilterX(this);
        
        end
        
        function UpdatePDA(this, assocWeights)
        % UpdatePDA - Performs UKF update step, for multiple measurements
        %             Update is performed according to the generic (J)PDAF equations [1] 
        %   
        %   Inputs:
        %       assoc_weights: a (1 x Nm+1) association weights matrix. The first index corresponds to the dummy measurement and
        %                       indices (2:Nm+1) correspond to measurements. Default = [0, ones(1,ObsNum)/ObsNum];
        %
        %   (NOTE: The measurement "this.Params.y" needs to be updated, when necessary, before calling this method) 
        %   
        %   Usage:
        %       (ukf.Params.y = y_new; % y_new is the new measurement)
        %       ukf.UpdateMulti(assocWeights);
        %
        %   [1] Y. Bar-Shalom, F. Daum and J. Huang, "The probabilistic data association filter," in IEEE Control Systems, vol. 29, no. 6, pp. 82-100, Dec. 2009.
        %
        %   See also UnscentedKalmanFilterX, Predict, Iterate, Smooth, resample.
        
            % Call SuperClass method
            UpdatePDA@KalmanFilterX(this, assocWeights);
        end
        
        function smoothedEstimates = Smooth(this, filteredEstimates)
        % Smooth - Performs UKF smoothing on a provided set of estimates
        %          (Based on [1])
        %   
        %   Inputs:
        %       filtered_estimates: a (1 x N) cell array, where N is the total filter iterations and each cell is a copy of this.Params after each iteration
        %   
        %   Outputs:
        %       smoothed_estimates: a copy of the input (1 x N) cell array filtered_estimates, where the .x and .P fields have been replaced with the smoothed estimates   
        %
        %   (Virtual inputs at each iteration)        
        %           -> filtered_estimates{k}.x          : Filtered state mean estimate at timestep k
        %           -> filtered_estimates{k}.P          : Filtered state covariance estimate at each timestep
        %           -> filtered_estimates{k+1}.x_pred   : Predicted state at timestep k+1
        %           -> filtered_estimates{k+1}.P_pred   : Predicted covariance at timestep k+1
        %           -> smoothed_estimates{k+1}.x        : Smoothed state mean estimate at timestep k+1
        %           -> smoothed_estimates{k+1}.P        : Smoothed state covariance estimate at timestep k+1 
        %       where, smoothed_estimates{N} = filtered_estimates{N} on initialisation
        %
        %   (NOTE: The filtered_estimates array can be accumulated by running "filtered_estimates{k} = ukf.Params" after each iteration of the filter recursion) 
        %   
        %   Usage:
        %       ukf.Smooth(filtered_estimates);
        %
        %   [1] S. S�rkk�, "Unscented Rauch-Tung-Striebel Smoother," in IEEE Transactions on Automatic Control, vol. 53, no. 3, pp. 845-849, April 2008.
        %
        %   See also UnscentedKalmanFilterX, Predict, Update, Iterate.
        
            if(nargin==2)
                smoothedEstimates = UnscentedKalmanFilterX_SmoothRTS(filteredEstimates);
            else
                smoothedEstimates = UnscentedKalmanFilterX_SmoothRTS(filteredEstimates,interval);
            end
        end
    end
end