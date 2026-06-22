classdef DopplerWrapper < matlab.System & coder.ExternalDependency
    % DopplerWrapper Invokes handwritten embedded C code in normal simulation mode
    
    methods(Access = protected)
        function setupImpl(obj)
            % Initialization phase
        end

        function [out_real, out_imag] = stepImpl(obj, in_real, in_imag)
            out_real = zeros(128, 64, 'single');
            out_imag = zeros(128, 64, 'single');
            
            coder.ceval('process_doppler_frame', ...
                        coder.rref(in_real), coder.rref(in_imag), ...
                        coder.wref(out_real), coder.wref(out_imag));
        end
        
        function resetImpl(obj)
            % Reset phase
        end

        % MANDATORY METHOD FOR MULTIPLE OUTPUT PORTS
        function [fx1, fx2] = isOutputFixedSizeImpl(obj)
            % Both output ports have a static, non-changing frame size [128 x 64]
            fx1 = true;
            fx2 = true;
        end

        function [sz1, sz2] = getOutputSizeImpl(obj)
            sz1 = [128 64]; sz2 = [128 64];
        end

        function [dt1, dt2] = getOutputDataTypeImpl(obj)
            dt1 = 'single'; dt2 = 'single';
        end

        function [cp1, cp2] = isOutputComplexImpl(obj)
            cp1 = false; cp2 = false;
        end
        
        function [cp1, cp2] = isInputComplexImpl(obj)
            cp1 = false; cp2 = false;
        end
    end
    
    methods(Static)
        function name = getDescriptiveName(~)
            name = 'DopplerWrapper';
        end
        
        function b = isSupportedContext(~)
            b = true;
        end
        
        function updateBuildInfo(buildInfo, context)
            thisDir = fileparts(mfilename('fullpath'));
            
            % Trace paths cleanly from the 'simulink_model/' directory
            srcDir = fullfile(thisDir, '..', 'embedded_c', 'src');
            incDir = fullfile(thisDir, '..', 'embedded_c', 'include');
            
            addSourceFiles(buildInfo, 'doppler_processing.c', srcDir);
            addIncludePaths(buildInfo, incDir);
        end
    end
end
