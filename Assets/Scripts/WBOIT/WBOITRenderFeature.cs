using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class WBOITRenderFeature : ScriptableRendererFeature
{
    public enum WeightFunction
    {
        NONE,
        W0,
        W1,
        W2,
        W3,
        W4
    }
    public WeightFunction weightFunction = WeightFunction.NONE;
    public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
    public class WBOITAccRenderPass : ScriptableRenderPass
    {
        public static readonly int accTex = Shader.PropertyToID("_AccTex");
        //public static readonly int alphaTex = Shader.PropertyToID("_AlphaTex");
        FilteringSettings m_filteringSettings;
        ProfilingSampler m_profilingSampler;
        RenderStateBlock m_stateBlock;

        List<ShaderTagId> m_ShaderTagIdList = new List<ShaderTagId>()
        {
            new ShaderTagId("WBOITAcc"),
        };

        public WBOITAccRenderPass(RenderQueueRange renderQueueRange) 
        {
            m_profilingSampler = new ProfilingSampler("WBOITAcc");
            m_filteringSettings = new FilteringSettings(renderQueueRange);
            m_stateBlock = new RenderStateBlock(RenderStateMask.Nothing);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref UnityEngine.Rendering.Universal.RenderingData renderingData)
        {
            Camera camera = renderingData.cameraData.camera;
            RenderTextureDescriptor temDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            temDescriptor.width = (int)(camera.pixelWidth);
            temDescriptor.height = (int)(camera.pixelHeight);
            temDescriptor.colorFormat = RenderTextureFormat.Default;
            cmd.GetTemporaryRT(accTex, temDescriptor);
            //cmd.GetTemporaryRT(alphaTex, temDescriptor);

            cmd.SetRenderTarget(accTex);
            cmd.ClearRenderTarget(true, true, Color.clear);
        }

        public override void Execute(ScriptableRenderContext context, ref UnityEngine.Rendering.Universal.RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("WBOITAcc");
            using (new ProfilingScope(cmd, m_profilingSampler))
            {
                Camera camera = renderingData.cameraData.camera;

                SortingCriteria sortingFlags = SortingCriteria.CommonTransparent;
                FilteringSettings filterSettings = m_filteringSettings;

                if (renderingData.cameraData.isSceneViewCamera)
                {
                    ConfigureTarget(accTex, depthAttachment);
                }
                else
                {
                    ConfigureTarget(accTex, Shader.PropertyToID("_CameraDepthAttachment"));
                }

                DrawingSettings drawSettings = CreateDrawingSettings(m_ShaderTagIdList, ref renderingData, sortingFlags);
                context.DrawRenderers(renderingData.cullResults, ref drawSettings, ref filterSettings, ref m_stateBlock);
            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    public class WBOITAlphaRenderPass : ScriptableRenderPass
    {
        public static readonly int alphaTex = Shader.PropertyToID("_AlphaTex");
        FilteringSettings m_filteringSettings;
        ProfilingSampler m_profilingSampler;
        RenderStateBlock m_stateBlock;

        List<ShaderTagId> m_ShaderTagIdList = new List<ShaderTagId>()
        {
            new ShaderTagId("WBOITAlpha"),
        };

        public WBOITAlphaRenderPass(RenderQueueRange renderQueueRange)
        {
            m_profilingSampler = new ProfilingSampler("WBOITAlpha");
            m_filteringSettings = new FilteringSettings(renderQueueRange);
            m_stateBlock = new RenderStateBlock(RenderStateMask.Nothing);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref UnityEngine.Rendering.Universal.RenderingData renderingData)
        {
            RenderTextureDescriptor temDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            temDescriptor.width = (int)(1920);
            temDescriptor.height = (int)(1080);
            temDescriptor.colorFormat = RenderTextureFormat.Default;

            //RenderTargetHandle renderTargetHandle = new RenderTargetHandle();
            //renderTargetHandle.Init("aaa");
  
            //cmd.GetTemporaryRT(accTex, temDescriptor);
            cmd.GetTemporaryRT(alphaTex, temDescriptor);

            cmd.SetRenderTarget(alphaTex);
            cmd.ClearRenderTarget(true, true, Color.white);
        }

        public override void Execute(ScriptableRenderContext context, ref UnityEngine.Rendering.Universal.RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("WBOITAlpha");
            using (new ProfilingScope(cmd, m_profilingSampler))
            {
                Camera camera = renderingData.cameraData.camera;

                SortingCriteria sortingFlags = SortingCriteria.CommonTransparent;
                FilteringSettings filterSettings = m_filteringSettings;

                ConfigureTarget(alphaTex);
                DrawingSettings drawSettings = CreateDrawingSettings(m_ShaderTagIdList, ref renderingData, sortingFlags);
                context.DrawRenderers(renderingData.cullResults, ref drawSettings, ref filterSettings, ref m_stateBlock);

            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    public class WBOITBlendRenderPass : ScriptableRenderPass
    {
        FilteringSettings m_filteringSettings;
        ProfilingSampler m_profilingSampler;
        RenderStateBlock m_stateBlock;

        public WBOITBlendRenderPass(RenderQueueRange renderQueueRange)
        {
            m_profilingSampler = new ProfilingSampler("WBOITBlend");
            m_filteringSettings = new FilteringSettings(renderQueueRange);
            m_stateBlock = new RenderStateBlock(RenderStateMask.Nothing);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref UnityEngine.Rendering.Universal.RenderingData renderingData)
        {
        }

        public override void Execute(ScriptableRenderContext context, ref UnityEngine.Rendering.Universal.RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("WBOITBlend");
            using (new ProfilingScope(cmd, m_profilingSampler))
            {
                Camera camera = renderingData.cameraData.camera;

                Material mat = new Material(Shader.Find("WBOIT"));
                cmd.Blit(camera.activeTexture, Shader.PropertyToID("_CameraColorAttachmentA"), mat, 2);
            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    WBOITAccRenderPass m_accRenderPass;
    WBOITAlphaRenderPass m_alphaRenderPass;
    WBOITBlendRenderPass m_blendRenderPass;

    public override void Create()
    {
        m_accRenderPass = new WBOITAccRenderPass(RenderQueueRange.transparent);
        m_accRenderPass.renderPassEvent = renderPassEvent;

        m_alphaRenderPass = new WBOITAlphaRenderPass(RenderQueueRange.transparent);
        m_alphaRenderPass.renderPassEvent = renderPassEvent;

        m_blendRenderPass = new WBOITBlendRenderPass(RenderQueueRange.transparent);
        m_blendRenderPass.renderPassEvent = renderPassEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref UnityEngine.Rendering.Universal.RenderingData renderingData)
    {
        // Can use MRT to merge acc pass and alpha pass.
        renderer.EnqueuePass(m_accRenderPass);
        renderer.EnqueuePass(m_alphaRenderPass);
        renderer.EnqueuePass(m_blendRenderPass);

        if(weightFunction == WeightFunction.NONE)
        {
            Shader.DisableKeyword("_WEIGHTED_ON");
            Shader.DisableKeyword("_WEIGHTED0");
            Shader.DisableKeyword("_WEIGHTED1");
            Shader.DisableKeyword("_WEIGHTED2");
            Shader.DisableKeyword("_WEIGHTED3");
            Shader.DisableKeyword("_WEIGHTED4");
        }
        else if(weightFunction == WeightFunction.W0)
        {
            Shader.EnableKeyword("_WEIGHTED_ON");
            Shader.EnableKeyword("_WEIGHTED0");
            Shader.DisableKeyword("_WEIGHTED1");
            Shader.DisableKeyword("_WEIGHTED2");
            Shader.DisableKeyword("_WEIGHTED3");
            Shader.DisableKeyword("_WEIGHTED4");
        }
        else if (weightFunction == WeightFunction.W1)
        {
            Shader.EnableKeyword("_WEIGHTED_ON");
            Shader.DisableKeyword("_WEIGHTED0");
            Shader.EnableKeyword("_WEIGHTED1");
            Shader.DisableKeyword("_WEIGHTED2");
            Shader.DisableKeyword("_WEIGHTED3");
            Shader.DisableKeyword("_WEIGHTED4");
        }
        else if (weightFunction == WeightFunction.W2)
        {
            Shader.EnableKeyword("_WEIGHTED_ON");
            Shader.DisableKeyword("_WEIGHTED0");
            Shader.DisableKeyword("_WEIGHTED1");
            Shader.EnableKeyword("_WEIGHTED2");
            Shader.DisableKeyword("_WEIGHTED3");
            Shader.DisableKeyword("_WEIGHTED4");
        }
        else if( weightFunction == WeightFunction.W3)
        {
            Shader.EnableKeyword("_WEIGHTED_ON");
            Shader.DisableKeyword("_WEIGHTED0");
            Shader.DisableKeyword("_WEIGHTED1");
            Shader.DisableKeyword("_WEIGHTED2");
            Shader.EnableKeyword("_WEIGHTED3");
            Shader.DisableKeyword("_WEIGHTED4");
        }
        else if(weightFunction == WeightFunction.W4)
        {
            Shader.EnableKeyword("_WEIGHTED_ON");
            Shader.DisableKeyword("_WEIGHTED0");
            Shader.DisableKeyword("_WEIGHTED1");
            Shader.DisableKeyword("_WEIGHTED2");
            Shader.DisableKeyword("_WEIGHTED3");
            Shader.EnableKeyword("_WEIGHTED4");
        }
    }

}
