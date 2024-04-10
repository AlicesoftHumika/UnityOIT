using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class MomentOITRenderFeature : ScriptableRendererFeature
{
    public static readonly int zeroMoment = Shader.PropertyToID("_ZeroMoment");
    public static readonly int moments = Shader.PropertyToID("_Moments");
    public static readonly int momentsSub = Shader.PropertyToID("_MomentsSub");

    public float bias = 5e-7f;
    public float overestimation = 0.25f;

    public bool moreMoments = true;

    public class GenerateMomentRenderPass : ScriptableRenderPass
    {
        FilteringSettings m_settings;
        ProfilingSampler m_profilingSampler;
        RenderStateBlock m_stateBlock;

        bool moreMoments;

        public GenerateMomentRenderPass(RenderQueueRange renderQueueRange, bool moreMoments) 
        {
            m_profilingSampler = new ProfilingSampler("GenerateMoment");
            m_settings = new FilteringSettings(renderQueueRange);
            m_stateBlock = new RenderStateBlock(RenderStateMask.Nothing);
            this.moreMoments = moreMoments;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref UnityEngine.Rendering.Universal.RenderingData renderingData)
        {
            base.OnCameraSetup(cmd, ref renderingData);

            Camera camera = renderingData.cameraData.camera;
            RenderTextureDescriptor temp = renderingData.cameraData.cameraTargetDescriptor;
            temp.width = (int)camera.scaledPixelWidth;
            temp.height = (int)camera.scaledPixelHeight;
            temp.colorFormat = RenderTextureFormat.Default;

            cmd.GetTemporaryRT(zeroMoment, temp);
            cmd.GetTemporaryRT(moments, temp);

            cmd.SetRenderTarget(zeroMoment);
            cmd.ClearRenderTarget(true, true, Color.clear);

            cmd.SetRenderTarget(moments);
            cmd.ClearRenderTarget(true, true, Color.clear);

            // MRT Setting.
            if (!moreMoments)
            {
                ConfigureTarget(new RenderTargetIdentifier[] { zeroMoment, moments });
            }
            else
            {
                cmd.GetTemporaryRT(momentsSub, temp);
                cmd.SetRenderTarget(momentsSub);
                cmd.ClearRenderTarget(true,true, Color.clear);

                ConfigureTarget(new RenderTargetIdentifier[] {zeroMoment, moments, momentsSub });
            }
        }

        public override void Execute(ScriptableRenderContext context, ref UnityEngine.Rendering.Universal.RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("GenerateMoment");
            using (new ProfilingScope(cmd, m_profilingSampler))
            {
                Camera camera = renderingData.cameraData.camera;
                SortingCriteria sortingCriteria = SortingCriteria.CommonTransparent;
                FilteringSettings filteringSettings = m_settings;

                ShaderTagId shaderTag = new ShaderTagId("GenerateMoment");
                if (moreMoments)
                {
                    shaderTag = new ShaderTagId("GenerateMoreMoment");
                }

                DrawingSettings drawingSettings = CreateDrawingSettings(shaderTag, ref renderingData, sortingCriteria);
                context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref filteringSettings, ref m_stateBlock);
            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            base.OnCameraCleanup(cmd);
        }
    }

    public class ReconstructTransmittanceRenderPass : ScriptableRenderPass
    {
        FilteringSettings m_settings;
        ProfilingSampler m_profilingSampler;
        RenderStateBlock m_stateBlock;

        public ReconstructTransmittanceRenderPass(RenderQueueRange renderQueueRange)
        {
            m_profilingSampler = new ProfilingSampler("MBOITGenerate");
            m_settings = new FilteringSettings(renderQueueRange);
            m_stateBlock = new RenderStateBlock(RenderStateMask.Nothing);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref UnityEngine.Rendering.Universal.RenderingData renderingData)
        {
            RenderTextureDescriptor temp = renderingData.cameraData.cameraTargetDescriptor;
            temp.width = 1920;
            temp.height = 1080;
            temp.colorFormat = RenderTextureFormat.Default;

            int transparentTexture = Shader.PropertyToID("_CameraTransparentTexture");

            cmd.GetTemporaryRT(transparentTexture, temp);

            cmd.SetRenderTarget(transparentTexture);
            cmd.ClearRenderTarget(true, true, Color.clear);

            ConfigureTarget(transparentTexture, Shader.PropertyToID("_CameraDepthAttachment"));
        }

        public override void Execute(ScriptableRenderContext context, ref UnityEngine.Rendering.Universal.RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("MBOITReconstruct");
            using (new ProfilingScope(cmd, m_profilingSampler))
            {
                Camera camera = renderingData.cameraData.camera;

                SortingCriteria sortingCriteria = SortingCriteria.CommonTransparent;
                FilteringSettings filteringSettings = m_settings;

                DrawingSettings drawingSettings = CreateDrawingSettings(new ShaderTagId("ReconstructTransmittance"), ref renderingData, sortingCriteria);
                context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref filteringSettings, ref m_stateBlock);
            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            base.OnCameraCleanup(cmd);
        }
    }

    public class CompositeRenderPass : ScriptableRenderPass
    {
        ProfilingSampler m_profilingSampler;

        public CompositeRenderPass(RenderQueueRange renderQueueRange)
        {
            m_profilingSampler = new ProfilingSampler("MBOITComposite");
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref UnityEngine.Rendering.Universal.RenderingData renderingData)
        {
        }

        public override void Execute(ScriptableRenderContext context, ref UnityEngine.Rendering.Universal.RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("MBOITComposite");
            using (new ProfilingScope(cmd, m_profilingSampler))
            {
                Material mat = new Material(Shader.Find("MomentOIT"));
                cmd.Blit(null, Shader.PropertyToID("_CameraColorAttachmentA"), mat, 2);
            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }

    GenerateMomentRenderPass m_generateMomentRenderPass;
    ReconstructTransmittanceRenderPass m_reconstructTransmittanceRenderPass;
    CompositeRenderPass m_compositeRenderPass;

    public override void Create()
    {
        m_generateMomentRenderPass = new GenerateMomentRenderPass(RenderQueueRange.transparent, moreMoments);
        m_generateMomentRenderPass.renderPassEvent = RenderPassEvent.AfterRenderingTransparents;

        m_reconstructTransmittanceRenderPass = new ReconstructTransmittanceRenderPass(RenderQueueRange.transparent);
        m_reconstructTransmittanceRenderPass.renderPassEvent = RenderPassEvent.AfterRenderingTransparents;

        m_compositeRenderPass = new CompositeRenderPass(RenderQueueRange.transparent);
        m_compositeRenderPass.renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref UnityEngine.Rendering.Universal.RenderingData renderingData)
    {
        Shader.SetGlobalFloat("_Bias", bias);
        Shader.SetGlobalFloat("_Overestimation", overestimation);

        if(moreMoments)
        {
            Shader.EnableKeyword("_MORE_MOMENTS");
        }
        else
        {
            Shader.DisableKeyword("_MORE_MOMENTS");
        }

        renderer.EnqueuePass(m_generateMomentRenderPass);
        renderer.EnqueuePass(m_reconstructTransmittanceRenderPass);
        renderer.EnqueuePass(m_compositeRenderPass);
    }
}
